import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Dismissible;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/snap_map_model.dart';
import '../providers/map_provider.dart';
import '../services/ai_mind_map_service.dart';
import '../services/local_llm_service.dart';
import '../services/local_model_service.dart';
import '../services/voice_input_service.dart';
import '../storage/hive_storage.dart';
import '../themes/app_theme.dart';
import 'mindmap_screen.dart';

class ChatAiScreen extends StatefulWidget {
  const ChatAiScreen({super.key});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  static const String _chatSessionsKey = 'chat_ai_sessions';
  static const String _activeChatSessionKey = 'chat_ai_active_session';
  static const String _greeting = 'What’s on the agenda today?';

  final HiveStorage _storage = HiveStorage();
  final VoiceInputService _voiceInputService = VoiceInputService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  List<_ChatSession> _sessions = [];
  String? _activeSessionId;
  bool _isThinking = false;
  bool _hasModel = false;
  bool _isHistoryOpen = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    LocalModelService.downloadProgress.addListener(_handleModelStateChanged);
    LocalModelService.isDownloading.addListener(_handleModelStateChanged);
    _loadChatSessions();
    _loadModelState();
  }

  @override
  void dispose() {
    LocalModelService.downloadProgress.removeListener(_handleModelStateChanged);
    LocalModelService.isDownloading.removeListener(_handleModelStateChanged);
    _controller.dispose();
    _scrollController.dispose();
    _voiceInputService.stopListening();
    super.dispose();
  }

  void _handleModelStateChanged() {
    _loadModelState();
  }

  void _loadModelState() async {
    final path = await LocalModelService.savedModelPath();
    if (!mounted) return;
    setState(() => _hasModel = path != null);
    if (path != null && !LocalLlmService.isReady) {
      await LocalLlmService.init(modelPath: path);
    }
  }

  void _loadChatSessions() {
    final rawSessions = _storage.getSetting(_chatSessionsKey, <dynamic>[]);
    final sessions = rawSessions is List
        ? rawSessions
              .whereType<Map>()
              .map((session) => _ChatSession.fromJson(session))
              .toList()
        : <_ChatSession>[];
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final activeId =
        _storage.getSetting(_activeChatSessionKey, null) as String?;
    _ChatSession? active;
    for (final session in sessions) {
      if (session.id == activeId) {
        active = session;
        break;
      }
    }

    setState(() {
      _sessions = sessions;
      _activeSessionId = active?.id ?? _newSessionId();
      _messages
        ..clear()
        ..addAll(
          active?.messages ??
              const [_ChatMessage(text: _greeting, isUser: false)],
        );
    });

    if (active == null) {
      _saveCurrentSession();
    }
  }

  Future<void> _saveCurrentSession() async {
    final sessionId = _activeSessionId ?? _newSessionId();
    _activeSessionId = sessionId;

    final session = _ChatSession(
      id: sessionId,
      title: _sessionTitle(_messages),
      updatedAt: DateTime.now(),
      messages: List<_ChatMessage>.from(_messages),
    );

    final updated = [
      session,
      ..._sessions.where((item) => item.id != sessionId),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _sessions = updated.take(20).toList();

    await _storage.saveSetting(
      _chatSessionsKey,
      _sessions.map((session) => session.toJson()).toList(),
    );
    await _storage.saveSetting(_activeChatSessionKey, sessionId);
  }

  void _startNewChat() {
    HapticFeedback.lightImpact();
    setState(() {
      _activeSessionId = _newSessionId();
      _isHistoryOpen = false;
      _messages
        ..clear()
        ..add(const _ChatMessage(text: _greeting, isUser: false));
    });
    _saveCurrentSession();
  }

  void _openChatHistory() {
    HapticFeedback.lightImpact();
    setState(() => _isHistoryOpen = true);
  }

  void _closeChatHistory() {
    if (_isHistoryOpen) {
      setState(() => _isHistoryOpen = false);
    }
  }

  void _selectSession(_ChatSession session) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeSessionId = session.id;
      _isHistoryOpen = false;
      _messages
        ..clear()
        ..addAll(session.messages);
    });
    _storage.saveSetting(_activeChatSessionKey, session.id);
    _scrollToBottom();
  }

  Future<void> _deleteSession(_ChatSession session) async {
    HapticFeedback.mediumImpact();
    final remaining = _sessions.where((item) => item.id != session.id).toList();

    setState(() {
      _sessions = remaining;
      if (_activeSessionId == session.id) {
        final next = remaining.isNotEmpty ? remaining.first : null;
        _activeSessionId = next?.id ?? _newSessionId();
        _messages
          ..clear()
          ..addAll(
            next?.messages ??
                const [_ChatMessage(text: _greeting, isUser: false)],
          );
      }
    });

    await _storage.saveSetting(
      _chatSessionsKey,
      _sessions.map((session) => session.toJson()).toList(),
    );
    await _storage.saveSetting(_activeChatSessionKey, _activeSessionId);
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isThinking) return;

    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isThinking = true;
    });
    await _saveCurrentSession();
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 450));
    if (!_hasModel) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(text: _downloadWaitMessage(), isUser: false),
        );
        _isThinking = false;
      });
      await _saveCurrentSession();
      _scrollToBottom();
      return;
    }

    late final _ChatMessage response;
    try {
      response = await _buildLocalResponse(text);
    } catch (_) {
      response = _buildFallbackResponse(text);
    }

    if (!mounted) return;
    setState(() {
      _messages.add(response);
      _isThinking = false;
    });
    await _saveCurrentSession();
    _scrollToBottom();
  }

  Future<void> _toggleVoiceInput() async {
    HapticFeedback.lightImpact();
    if (_isListening) {
      await _voiceInputService.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final available = await _voiceInputService.initSpeech();
    if (!mounted) return;
    if (!available) {
      _showVoiceUnavailableDialog();
      return;
    }

    setState(() => _isListening = true);
    await _voiceInputService.startListening(
      onResult: (text) {
        if (!mounted || text.trim().isEmpty) return;
        _controller
          ..text = text
          ..selection = TextSelection.collapsed(offset: text.length);
      },
    );
  }

  void _showVoiceUnavailableDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Voice input unavailable'),
        content: const Text(
          'Please allow microphone permission and try again.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<_ChatMessage> _buildLocalResponse(String input) async {
    const modelPrefix = 'Local study mode is ready.\n\n';
    final lower = input.toLowerCase();

    if (lower.contains('summary') || lower.contains('summarize')) {
      final summary = await LocalLlmService.generateSummary(input);
      return _ChatMessage(
        text: summary.isEmpty
            ? 'Paste a longer note and I can summarize it.'
            : '${modelPrefix}Summary:\n$summary',
        isUser: false,
      );
    }

    if (lower.contains('action') ||
        lower.contains('todo') ||
        lower.contains('task')) {
      final parsed = AiMindMapService.generateNotebookStyleMap(input);
      final actionNode = parsed.nodes
          .where((node) => node.title == 'Action Items')
          .toList();
      final actions = actionNode
          .expand((node) => node.children)
          .take(6)
          .map((node) => '- ${node.title}')
          .join('\n');
      return _ChatMessage(
        text: actions.isEmpty
            ? 'I did not find clear action items. Add words like need to, must, todo, build, create, or fix.'
            : '${modelPrefix}Action items:\n$actions',
        isUser: false,
      );
    }

    if (lower.contains('question') ||
        lower.contains('quiz') ||
        lower.contains('study')) {
      final questions = await LocalLlmService.generateChatReply(
        'Create 6 useful study questions from this:\n\n$input',
      );
      return _ChatMessage(
        text: questions.isEmpty
            ? 'Paste study notes and I can turn them into review questions.'
            : '${modelPrefix}Study questions:\n$questions',
        isUser: false,
      );
    }

    if (lower.contains('mind map') ||
        lower.contains('mindmap') ||
        lower.contains('map banao') ||
        lower.contains('make map') ||
        lower.contains('structure') ||
        lower.contains('organize') ||
        input.length > 90) {
      final parsed = await LocalLlmService.generateMindMapFromText(input);
      if (parsed.nodes.isEmpty) {
        return const _ChatMessage(
          text: 'I need a little more detail to structure this.',
          isUser: false,
        );
      }

      if (!mounted) {
        return const _ChatMessage(text: 'Mind map created.', isUser: false);
      }
      final provider = Provider.of<MapProvider>(context, listen: false);
      await provider.saveMap(parsed);

      final buffer = StringBuffer('Mind map: ${parsed.title}');
      for (final node in parsed.nodes.take(5)) {
        buffer.writeln('\n${node.title}');
        for (final child in node.children.take(3)) {
          buffer.writeln('- ${child.title}');
        }
      }
      return _ChatMessage(
        text: '$modelPrefix${buffer.toString()}',
        isUser: false,
        map: parsed,
      );
    }

    return _ChatMessage(
      text: '$modelPrefix${await LocalLlmService.generateChatReply(input)}',
      isUser: false,
    );
  }

  _ChatMessage _buildFallbackResponse(String input) {
    final parsed = AiMindMapService.generateNotebookStyleMap(input);
    final points = parsed.nodes
        .expand((node) => node.children)
        .take(5)
        .map((node) => '- ${node.title}')
        .join('\n');
    return _ChatMessage(
      text: points.isEmpty
          ? 'I can help with that. Add a little more detail and try again.'
          : 'Here is what I found:\n$points',
      isUser: false,
    );
  }

  String _downloadWaitMessage() {
    return 'The AI model is still downloading. Please wait a moment, then ask again.';
  }

  String _newSessionId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _sessionTitle(List<_ChatMessage> messages) {
    for (final message in messages) {
      final text = message.text.trim();
      if (message.isUser && text.isNotEmpty) {
        return text.length > 34 ? '${text.substring(0, 34)}...' : text;
      }
    }
    return 'New chat';
  }

  void _openGeneratedMap(SnapMapData map) {
    final provider = Provider.of<MapProvider>(context, listen: false);
    provider.selectMap(map);
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (context) => const MindmapScreen()));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: bgLight,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: surface.withValues(alpha: 0.72),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(
            CupertinoIcons.chevron_left,
            color: textDark,
            size: 28,
          ),
        ),
        middle: Text('Chat AI', style: headingStyle(fontSize: 18)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
              onPressed: _openChatHistory,
              child: const Icon(CupertinoIcons.folder, size: 21),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                    itemCount: _messages.length + (_isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isThinking && index == _messages.length) {
                        return const _ThinkingBubble();
                      }
                      return _MessageBubble(
                        message: _messages[index],
                        onOpenMap: _openGeneratedMap,
                      );
                    },
                  ),
                ),
                _Composer(
                  controller: _controller,
                  isListening: _isListening,
                  onVoice: _toggleVoiceInput,
                  onSend: _sendMessage,
                ),
              ],
            ),
            if (_isHistoryOpen)
              GestureDetector(
                onTap: _closeChatHistory,
                child: Container(color: Colors.black.withValues(alpha: 0.32)),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              left: _isHistoryOpen
                  ? 0
                  : -(MediaQuery.of(context).size.width * 0.82),
              width: MediaQuery.of(context).size.width * 0.82,
              child: _ChatHistoryDrawer(
                sessions: _sessions,
                activeSessionId: _activeSessionId,
                onNewChat: _startNewChat,
                onSelect: _selectSession,
                onDelete: _deleteSession,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHistoryDrawer extends StatelessWidget {
  final List<_ChatSession> sessions;
  final String? activeSessionId;
  final VoidCallback onNewChat;
  final void Function(_ChatSession session) onSelect;
  final Future<void> Function(_ChatSession session) onDelete;

  const _ChatHistoryDrawer({
    required this.sessions,
    required this.activeSessionId,
    required this.onNewChat,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgLight,
        border: Border(
          right: BorderSide(color: textDark.withValues(alpha: 0.08)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(8, 0),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.bubble_left_bubble_right_fill,
                      color: primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Snap Chat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: headingStyle(
                            fontSize: 22,
                            color: textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bodyStyle(
                            fontSize: 13,
                            color: textMid,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONVERSATIONS',
                          style: bodyStyle(
                            fontSize: 12,
                            color: textMid,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jump between recent chats',
                          style: bodyStyle(
                            fontSize: 14,
                            color: textMid,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 48),
                    onPressed: onNewChat,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.plus,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: sessions.isEmpty
                    ? Center(
                        child: Text(
                          'No chats yet',
                          style: bodyStyle(
                            color: textMid,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: sessions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return Dismissible(
                            key: ValueKey(session.id),
                            background: const _DeleteBackground(
                              alignment: Alignment.centerLeft,
                            ),
                            secondaryBackground: const _DeleteBackground(
                              alignment: Alignment.centerRight,
                            ),
                            onDismissed: (_) => onDelete(session),
                            child: _ChatSessionTile(
                              session: session,
                              isActive: session.id == activeSessionId,
                              onTap: () => onSelect(session),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatSessionTile extends StatelessWidget {
  final _ChatSession session;
  final bool isActive;
  final VoidCallback onTap;

  const _ChatSessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? primary.withValues(alpha: 0.1) : surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? primary : textDark.withValues(alpha: 0.08),
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle(
                      fontSize: 16,
                      color: textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    session.labelDate,
                    style: bodyStyle(
                      fontSize: 13,
                      color: textMid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  final Alignment alignment;

  const _DeleteBackground({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(CupertinoIcons.delete, color: Colors.white, size: 22),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onVoice;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.isListening,
    required this.onVoice,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: textDark.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              placeholder: 'Ask or paste notes',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: textDark.withValues(alpha: 0.08)),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onVoice,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isListening ? const Color(0xFFFF3B30) : textDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isListening ? CupertinoIcons.stop_fill : CupertinoIcons.mic,
                color: isListening
                    ? Colors.white
                    : (isDarkMode ? const Color(0xFF121212) : Colors.white),
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.arrow_up,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final void Function(SnapMapData map) onOpenMap;

  const _MessageBubble({required this.message, required this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: message.isUser ? primary : surface,
          borderRadius: BorderRadius.circular(18),
          border: message.isUser
              ? null
              : Border.all(color: textDark.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: bodyStyle(
                color: message.isUser ? Colors.white : textDark,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (message.map != null) ...[
              const SizedBox(height: 10),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: textDark,
                borderRadius: BorderRadius.circular(14),
                onPressed: () => onOpenMap(message.map!),
                child: Text(
                  'Open Mind Map',
                  style: bodyStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: textDark.withValues(alpha: 0.08)),
        ),
        child: const CupertinoActivityIndicator(radius: 9),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final SnapMapData? map;

  const _ChatMessage({required this.text, required this.isUser, this.map});

  factory _ChatMessage.fromJson(Map<dynamic, dynamic> json) {
    return _ChatMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'isUser': isUser};
  }
}

class _ChatSession {
  final String id;
  final String title;
  final DateTime updatedAt;
  final List<_ChatMessage> messages;

  const _ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  String get labelDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);
    if (date == today) return 'Today';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }

  factory _ChatSession.fromJson(Map<dynamic, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map((message) => _ChatMessage.fromJson(message))
              .toList()
        : <_ChatMessage>[];

    return _ChatSession(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'New chat',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: messages.isEmpty
          ? const [
              _ChatMessage(text: _ChatAiScreenState._greeting, isUser: false),
            ]
          : messages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }
}
