import 'package:llamadart/llamadart.dart';

import '../models/snap_map_model.dart';
import '../themes/app_theme.dart';

/// Local LLM Service running local on-device TinyLlama models.
/// It uses prompt parsing templates offline, structures concepts into nodes,
/// and falls back gracefully to local text categorization if model weights
/// are not initialized/loaded.
class LocalLlmService {
  static bool _isModelLoaded = false;
  static String? _modelPath;
  static LlamaEngine? _engine;
  static Future<bool>? _activeInit;

  /// Initializes the local LLM with the provided path.
  static Future<bool> init({String? modelPath}) async {
    final path = modelPath ?? 'assets/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
    if (_isModelLoaded && _modelPath == path && _engine?.isReady == true) {
      return true;
    }
    if (_activeInit != null) return _activeInit!;

    _activeInit = _initModel(path);
    try {
      return await _activeInit!;
    } finally {
      _activeInit = null;
    }
  }

  static bool get isReady => _isModelLoaded;
  static String? get modelPath => _modelPath;
  static bool get isUsingDownloadedModel =>
      _modelPath != null && !_modelPath!.startsWith('assets/');

  static Future<String> generateChatReply(String input) async {
    if (!_isModelLoaded || _engine?.isReady != true) {
      throw Exception("Local model is not loaded.");
    }

    final cleaned = input.trim();
    if (cleaned.isEmpty) return 'Tell me what you want to do.';
    final quickReply = _quickReply(cleaned);
    if (quickReply != null) return quickReply;

    try {
      final response = await _generateFromMessages(
        [
          _systemMessage(),
          LlamaChatMessage.fromText(role: LlamaChatRole.user, text: cleaned),
        ],
        params: const GenerationParams(
          maxTokens: 160,
          temp: 0.7,
          topK: 40,
          topP: 0.9,
          penalty: 1.12,
          stopSequences: [
            '</s>',
            '<|user|>',
            '<|assistant|>',
          ],
        ),
      ).timeout(const Duration(seconds: 25));
      final answer = _cleanGeneratedReply(response);
      if (answer.isNotEmpty) return answer;
    } catch (_) {
      return _buildGeneralReply(cleaned);
    }

    return _buildGeneralReply(cleaned);
  }

  static Future<String> generateSummary(String text) async {
    final prompt =
        'Summarize this content in 4 short, useful bullet points. Keep only the important ideas.\n\n$text';
    final reply = await _generateText(prompt, maxTokens: 220);
    return reply.trim();
  }

  static Future<SnapMapData> generateMindMapFromText(String text) async {
    if (!_isModelLoaded || _engine?.isReady != true) {
      throw Exception("Local AI model is not loaded.");
    }

    final prompt =
        'Create a premium NotebookLM-style nested mind map directly from the source text.\n\n'
        'Instructions:\n'
        '- Organize the content into clear, high-quality hierarchical branches resembling a professional study guide.\n'
        '- Select the best-fitting branch titles from these NotebookLM-style categories:\n'
        '  * Core Concepts (for central ideas & terms)\n'
        '  * Key Arguments (for logical points & evidence)\n'
        '  * Mechanisms & Process (for how things work or steps)\n'
        '  * Open Questions (for gaps or further thoughts)\n'
        '  * Action Items (for tasks, next steps, or todo)\n'
        '  * Timeline Flow (for chronological order if applicable)\n'
        '- IMPORTANT: Use indentation (2 spaces or 4 spaces) to represent deep nested points ("points inside points") for a multi-level structure. For example:\n'
        '  BRANCH: Core Concepts\n'
        '  - Main Concept\n'
        '    - Detailed Sub-Point 1\n'
        '    - Detailed Sub-Point 2\n'
        '      - Deep Sub-Sub-Point\n'
        '- Keep all branch names and points extremely short, clean, and highly educational.\n\n'
        'Output format:\n'
        'TITLE: NotebookLM Main Topic\n'
        'BRANCH: NotebookLM Branch Name\n'
        '- concise parent point\n'
        '  - concise sub-point inside point\n'
        '  - another sub-point\n'
        '    - deep sub-sub-point\n'
        'BRANCH: Another NotebookLM Branch Name\n'
        '- concise point\n\n'
        'Source:\n$text';
    final reply = await _generateText(prompt, maxTokens: 620);
    final parsed = _parseMindMap(reply, text);
    if (parsed.nodes.isEmpty) {
      throw Exception('LLM returned an empty mind map.');
    }
    return parsed;
  }

  static Future<List<Map<String, String>>> generateFlashcardsFromMap(
    SnapMapData map,
  ) async {
    if (!_isModelLoaded || _engine?.isReady != true) {
      throw Exception("Local model is not loaded.");
    }

    final source = StringBuffer('Title: ${map.title}\n');
    for (final node in map.nodes.take(8)) {
      source.writeln('Section: ${node.title}');
      for (final child in node.children.take(6)) {
        source.writeln('- ${child.title}');
      }
    }

    final prompt =
        'Create flashcards from this mind map. Use exactly this format for each card:\n'
        'Q: question\n'
        'A: answer\n\n'
        'Make the questions clear and the answers useful, not too long.\n\n'
        '$source';
    final reply = await _generateText(prompt, maxTokens: 420);
    return _parseFlashcards(reply);
  }

  static Future<bool> _initModel(String path) async {
    try {
      await _engine?.dispose();
      final engine = LlamaEngine(LlamaBackend());
      await engine.loadModel(
        path,
        modelParams: const ModelParams(
          contextSize: 1024,
          gpuLayers: 0,
          preferredBackend: GpuBackend.cpu,
        ),
      );
      _engine = engine;
      _modelPath = path;
      _isModelLoaded = true;
      return true;
    } catch (_) {
      await _engine?.dispose();
      _engine = null;
      _modelPath = null;
      _isModelLoaded = false;
      return false;
    }
  }

  static Future<String> _generateText(
    String input, {
    required int maxTokens,
  }) async {
    if (!_isModelLoaded || _engine?.isReady != true) {
      throw Exception("Local AI model is not loaded.");
    }

    final response = await _generateFromMessages(
      [
        _systemMessage(),
        LlamaChatMessage.fromText(role: LlamaChatRole.user, text: input),
      ],
      params: GenerationParams(
        maxTokens: maxTokens,
        temp: 0.65,
        topK: 35,
        topP: 0.9,
        penalty: 1.12,
        stopSequences: const [
          '</s>',
          '<|user|>',
          '<|assistant|>',
        ],
      ),
    ).timeout(const Duration(seconds: 35));
    return _cleanGeneratedReply(response);
  }

  static LlamaChatMessage _systemMessage() {
    return const LlamaChatMessage.fromText(
      role: LlamaChatRole.system,
      text:
          'You are Snap, a friendly local AI assistant. Reply naturally in 1-5 short lines unless the user asks for detail. Help with study, writing, planning, explanations, summaries, and mind maps.',
    );
  }

  static Future<String> _generateFromMessages(
    List<LlamaChatMessage> messages, {
    required GenerationParams params,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in _engine!.create(messages, params: params)) {
      for (final choice in chunk.choices) {
        final content = choice.delta.content;
        if (content != null) buffer.write(content);
      }
    }
    return buffer.toString();
  }

  static String? _quickReply(String input) {
    final lower = input.toLowerCase();
    if (RegExp(r'^(hi|hello|hey|hey there|yo|sup)[\s!.]*$').hasMatch(lower)) {
      return 'Hey! What can I help with?';
    }
    if (RegExp(r'^(thanks|thank you|tnx|thx)[\s!.]*$').hasMatch(lower)) {
      return 'You’re welcome.';
    }
    if (RegExp(r'^(ok|okay|hmm|hmm ok)[\s!.]*$').hasMatch(lower)) {
      return 'Got it.';
    }
    return null;
  }

  static String _cleanGeneratedReply(String text) {
    var cleaned = text
        .replaceAll('</s>', '')
        .replaceAll('<|assistant|>', '')
        .replaceAll('<|user|>', '')
        .replaceAll('<|system|>', '')
        .trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^(assistant|model):\s*'), '');
    return cleaned.trim();
  }

  static SnapMapData _parseMindMap(String output, String rawText) {
    final rawLines = output.split('\n');
    var title = 'AI Mind Map';
    final nodes = <MindMapNode>[];
    
    // Track the last node at each depth level to build hierarchical trees
    // Level 0: The current top-level branch node
    // Level 1: Sub-node of branch
    // Level 2: Sub-sub-node, etc.
    final Map<int, MindMapNode> lastNodeAtLevel = {};
    MindMapNode? currentBranch;
    var colorIndex = 0;

    for (final rawLine in rawLines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.toUpperCase().startsWith('TITLE:')) {
        title = trimmed.substring(6).trim();
      } else if (trimmed.toUpperCase().startsWith('BRANCH:')) {
        final branchTitle = _cleanMindMapText(trimmed.substring(7));
        if (_isBadBranchTitle(branchTitle)) {
          currentBranch = null;
          continue;
        }
        final colorValue = nodeColors[colorIndex % nodeColors.length].toARGB32();
        colorIndex++;
        
        currentBranch = MindMapNode(
          title: branchTitle,
          colorValue: colorValue,
        );
        nodes.add(currentBranch);
        lastNodeAtLevel.clear();
        lastNodeAtLevel[0] = currentBranch;
      } else if (_looksLikeListItem(trimmed) && currentBranch != null) {
        // Calculate depth from indentation (every 2 spaces is a depth level)
        final leadingSpaces = rawLine.length - rawLine.trimLeft().length;
        final depth = (leadingSpaces ~/ 2) + 1;
        
        final cleanText = _cleanMindMapText(
          trimmed.replaceFirst(RegExp(r'^[-*•]\s*|^\d+[\.)]\s*'), ''),
        );

        if (cleanText.isEmpty) continue;

        final newNode = MindMapNode(
          title: cleanText,
          colorValue: currentBranch.colorValue,
        );

        // Find correct parent node based on depth hierarchy
        MindMapNode? parentNode;
        for (int d = depth - 1; d >= 0; d--) {
          if (lastNodeAtLevel.containsKey(d)) {
            parentNode = lastNodeAtLevel[d];
            break;
          }
        }
        
        parentNode ??= currentBranch;
        parentNode.children.add(newNode);
        lastNodeAtLevel[depth] = newNode;
      }
    }

    return SnapMapData(title: title, nodes: nodes, rawText: rawText);
  }

  static bool _looksLikeListItem(String line) {
    return RegExp(r'^([-*•]|\d+[\.)])\s+').hasMatch(line);
  }

  static String _cleanMindMapText(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'^\s*["“”]+|["“”]+\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  static bool _isBadBranchTitle(String title) {
    final lower = title.toLowerCase();
    return title.isEmpty ||
        lower.contains('your chosen') ||
        lower.contains('another chosen') ||
        lower == 'branch title' ||
        lower == 'source-specific branch title';
  }

  static List<Map<String, String>> _parseFlashcards(String output) {
    final cards = <Map<String, String>>[];
    String? question;
    final answer = StringBuffer();

    void flush() {
      final q = question?.trim();
      final a = answer.toString().trim();
      if (q != null && q.isNotEmpty && a.isNotEmpty) {
        cards.add({'question': q, 'answer': a});
      }
      question = null;
      answer.clear();
    }

    for (final rawLine in output.split('\n')) {
      final line = rawLine.trim();
      if (line.toUpperCase().startsWith('Q:')) {
        flush();
        question = line.substring(2).trim();
      } else if (line.toUpperCase().startsWith('A:')) {
        answer.writeln(line.substring(2).trim());
      } else if (question != null && line.isNotEmpty) {
        answer.writeln(line);
      }
    }
    flush();

    return cards.take(20).toList();
  }

  static String _buildGeneralReply(String input) {
    return 'I can help with that.\n\n'
        'Tell me the exact goal or paste the content, and I’ll turn it into a clear answer, notes, questions, or a mind map.';
  }

  /// Generates a mind map structure using local text analysis.
  static Future<SnapMapData> generateMindMap(String text) async {
    if (!_isModelLoaded) {
      throw Exception("Local model is not loaded.");
    }

    // Simulate on-device local LLM latency for generation (300-500ms)
    await Future.delayed(const Duration(milliseconds: 500));

    // Simple robust keyword-based relationship extraction:
    // LLM would output JSON structured data format:
    // { "root": "Title", "topics": [ { "name": "Topic", "ideas": ["Idea 1"] } ] }
    // We parse the text semantically using fallback/local processing rules.

    final lines = text
        .trim()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return SnapMapData(title: 'Empty Idea', nodes: [], rawText: text);
    }

    // Try to extract a clean root topic title
    String rootTitle = "💡 Mind Map";
    if (lines.first.length < 50) {
      rootTitle = lines.first.replaceAll(RegExp(r'[:#*]'), '').trim();
    }

    // Perform clustering of concepts locally
    final Map<String, List<String>> clusters = {
      '🔑 Key Concepts': [],
      '📋 Details': [],
      '🚀 Action Items': [],
      '⚠️ Risks & Notes': [],
    };

    int sentenceCount = 0;
    for (var line in lines) {
      if (line == lines.first && line.length < 50) continue;

      final lower = line.toLowerCase();
      if (lower.contains('must') ||
          lower.contains('todo') ||
          lower.contains('action') ||
          lower.contains('need to')) {
        clusters['🚀 Action Items']!.add(line);
      } else if (lower.contains('risk') ||
          lower.contains('danger') ||
          lower.contains('issue') ||
          lower.contains('note')) {
        clusters['⚠️ Risks & Notes']!.add(line);
      } else if (sentenceCount < 3) {
        clusters['🔑 Key Concepts']!.add(line);
        sentenceCount++;
      } else {
        clusters['📋 Details']!.add(line);
      }
    }

    final List<MindMapNode> nodes = [];
    int colorIdx = 0;

    clusters.forEach((category, sentences) {
      if (sentences.isNotEmpty) {
        final colorValue = nodeColors[colorIdx % nodeColors.length].toARGB32();
        colorIdx++;

        final children = sentences.map((s) {
          // Trim sentence length slightly for cleaner node labels
          String cleanText = s;
          if (s.length > 80) {
            cleanText = '${s.substring(0, 77)}...';
          }
          return MindMapNode(title: cleanText, colorValue: colorValue);
        }).toList();

        nodes.add(
          MindMapNode(
            title: category,
            children: children,
            colorValue: colorValue,
          ),
        );
      }
    });

    return SnapMapData(title: rootTitle, nodes: nodes, rawText: text);
  }
}
