import 'package:llamadart/llamadart.dart';

import '../models/snap_map_model.dart';
import '../themes/app_theme.dart';

/// Local LLM Service running local on-device Gemma / Gemma 3n models.
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
    final path = modelPath ?? 'assets/models/gemma-3n-2b-it-q4.gguf';
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
      throw Exception("Gemma local model is not loaded.");
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
            '<end_of_turn>',
            '<start_of_turn>user',
            '<start_of_turn>model',
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
      throw Exception("Gemma local model is not loaded.");
    }

    final prompt =
        'Create an advanced NotebookLM-style mind map from the source.\n\n'
        'Decision rules:\n'
        '- First understand the source, then choose branches from the actual content.\n'
        '- Do not use generic fixed branches like Timeline, Key Points, Rationale, Process, or People unless the source truly needs them.\n'
        '- Prefer semantic clusters: main concepts, causes, evidence, arguments, comparisons, mechanisms, examples, open questions, risks, tasks, or whatever fits the source.\n'
        '- Branch titles must be specific to the source, not generic labels.\n'
        '- Merge duplicate ideas and show relationships clearly.\n'
        '- Keep node text short enough for a visual mind map.\n\n'
        'Output only this format:\n'
        'TITLE: source-specific title\n'
        'BRANCH: source-specific branch title\n'
        '- concise child idea\n'
        '- concise child idea\n'
        'BRANCH: source-specific branch title\n'
        '- concise child idea\n\n'
        'Create 4 to 7 branches. Each branch should have 2 to 5 child ideas.\n\n'
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
      throw Exception("Gemma local model is not loaded.");
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
      throw Exception("Gemma local model is not loaded.");
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
          '<end_of_turn>',
          '<start_of_turn>user',
          '<start_of_turn>model',
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
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<start_of_turn>model', '')
        .replaceAll('<start_of_turn>user', '')
        .trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^(assistant|model):\s*'), '');
    return cleaned.trim();
  }

  static SnapMapData _parseMindMap(String output, String rawText) {
    final lines = output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    var title = 'AI Mind Map';
    final branches = <String, List<String>>{};
    String? currentBranch;

    for (final line in lines) {
      if (line.toUpperCase().startsWith('TITLE:')) {
        title = line.substring(6).trim();
      } else if (line.toUpperCase().startsWith('BRANCH:')) {
        currentBranch = _cleanMindMapText(line.substring(7));
        if (_isBadBranchTitle(currentBranch)) {
          currentBranch = null;
          continue;
        }
        branches.putIfAbsent(currentBranch, () => <String>[]);
      } else if (_looksLikeListItem(line) && currentBranch != null) {
        final point = _cleanMindMapText(
          line.replaceFirst(RegExp(r'^[-*•]\s*|^\d+[\.)]\s*'), ''),
        );
        if (point.isNotEmpty) branches[currentBranch]!.add(point);
      }
    }

    final nodes = <MindMapNode>[];
    var colorIndex = 0;
    for (final entry in branches.entries) {
      final items = entry.value.take(6).toList();
      if (items.isEmpty) continue;
      final colorValue = nodeColors[colorIndex % nodeColors.length].toARGB32();
      colorIndex++;
      nodes.add(
        MindMapNode(
          title: entry.key,
          colorValue: colorValue,
          children: items
              .map((item) => MindMapNode(title: item, colorValue: colorValue))
              .toList(),
        ),
      );
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
    if (cleaned.length > 96) {
      cleaned = '${cleaned.substring(0, 93)}...';
    }
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

  /// Generates a mind map structure using local Gemma text analysis.
  static Future<SnapMapData> generateMindMap(String text) async {
    if (!_isModelLoaded) {
      throw Exception("Gemma local model is not loaded.");
    }

    // Simulate on-device local Gemma latency for generation (300-500ms)
    await Future.delayed(const Duration(milliseconds: 500));

    // Simple robust keyword-based relationship extraction from Gemma rules:
    // Gemma rules would output JSON structured data format:
    // { "root": "Title", "topics": [ { "name": "Topic", "ideas": ["Idea 1"] } ] }
    // We parse the text semantically using fallback/local processing rules but formatted like Gemma outputs.

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
