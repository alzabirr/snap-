import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show AlwaysStoppedAnimation, Colors, LinearProgressIndicator;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/snap_map_model.dart';
import '../providers/map_provider.dart';
import '../services/ai_mind_map_service.dart';
import '../services/local_llm_service.dart';
import '../services/local_model_service.dart';
import '../themes/app_theme.dart';
import 'mindmap_screen.dart';

class ChatAiScreen extends StatefulWidget {
  const ChatAiScreen({super.key});

  @override
  State<ChatAiScreen> createState() => _ChatAiScreenState();
}

class _ChatAiScreenState extends State<ChatAiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'Ask anything about your notes.',
      isUser: false,
    ),
  ];
  bool _isThinking = false;
  bool _hasModel = false;

  @override
  void initState() {
    super.initState();
    LocalModelService.downloadProgress.addListener(_handleModelStateChanged);
    LocalModelService.isDownloading.addListener(_handleModelStateChanged);
    _loadModelState();
  }

  @override
  void dispose() {
    LocalModelService.downloadProgress.removeListener(_handleModelStateChanged);
    LocalModelService.isDownloading.removeListener(_handleModelStateChanged);
    _controller.dispose();
    _scrollController.dispose();
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

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isThinking) return;

    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isThinking = true;
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 450));
    final response = await _buildLocalResponse(text);

    if (!mounted) return;
    setState(() {
      _messages.add(response);
      _isThinking = false;
    });
    _scrollToBottom();
  }

  Future<_ChatMessage> _buildLocalResponse(String input) async {
    final modelPrefix = _hasModel
        ? 'Local model mode is ready.\n\n'
        : '';
    final lower = input.toLowerCase();
    final wantsAiFeature = lower.contains('summary') ||
        lower.contains('summarize') ||
        lower.contains('action') ||
        lower.contains('todo') ||
        lower.contains('task') ||
        lower.contains('question') ||
        lower.contains('quiz') ||
        lower.contains('study') ||
        lower.contains('mind map') ||
        lower.contains('mindmap') ||
        lower.contains('map banao') ||
        lower.contains('make map') ||
        lower.contains('structure') ||
        lower.contains('organize') ||
        input.length > 90;

    if (wantsAiFeature && !_hasModel) {
      return const _ChatMessage(
        text:
            'Local AI model is still downloading in Settings. Once it is ready, I can chat, make mind maps, summarize notes, extract actions, and create study questions offline.',
        isUser: false,
      );
    }

    if (lower.contains('summary') || lower.contains('summarize')) {
      final parsed = AiMindMapService.generateNotebookStyleMap(input);
      final summary = parsed.nodes
          .where((node) => node.title == 'Core Summary' || node.title == 'Key Ideas')
          .expand((node) => node.children)
          .take(6)
          .map((node) => '- ${node.title}')
          .join('\n');
      return _ChatMessage(
        text: summary.isEmpty
            ? 'Paste a longer note and I can summarize it.'
            : '${modelPrefix}Summary:\n$summary',
        isUser: false,
      );
    }

    if (lower.contains('action') || lower.contains('todo') || lower.contains('task')) {
      final parsed = AiMindMapService.generateNotebookStyleMap(input);
      final actionNode = parsed.nodes.where((node) => node.title == 'Action Items').toList();
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

    if (lower.contains('question') || lower.contains('quiz') || lower.contains('study')) {
      final parsed = AiMindMapService.generateNotebookStyleMap(input);
      final questions = parsed.nodes
          .where((node) => node.title == 'Questions' || node.title == 'Key Ideas')
          .expand((node) => node.children)
          .take(6)
          .map((node) => '- What should you remember about ${node.title}?')
          .join('\n');
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
      final parsed = AiMindMapService.generateNotebookStyleMap(input);
      if (parsed.nodes.isEmpty) {
        return const _ChatMessage(
          text: 'I need a little more detail to structure this.',
          isUser: false,
        );
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

    if (lower.contains('hello') || lower.contains('hi')) {
      return _ChatMessage(
        text:
            '${modelPrefix}Hi. Paste your notes and say “make a mind map”. I will save it and open it for you.',
        isUser: false,
      );
    }

    return _ChatMessage(
      text: _hasModel
          ? 'Paste a source note and say “make a mind map”. I will create a NotebookLM-style map with summary, key ideas, questions, timeline, actions, and risks.'
          : 'Local AI model is still downloading in Settings. After it is ready, paste notes and say “make a mind map”.',
      isUser: false,
    );
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
        middle: Text('Chat AI', style: headingStyle(fontSize: 18)),
      ),
      child: SafeArea(
        child: Column(
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
            _Composer(controller: _controller, onSend: _sendMessage),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: textDark.withValues(alpha: 0.06))),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: textDark.withValues(alpha: 0.08)),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
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
          color: message.isUser ? primary : Colors.white,
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
          color: Colors.white,
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
}
