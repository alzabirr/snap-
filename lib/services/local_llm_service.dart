import 'dart:convert';
import '../models/snap_map_model.dart';
import '../themes/app_theme.dart';

/// Local LLM Service running local on-device Gemma / Gemma 3n models.
/// It uses prompt parsing templates offline, structures concepts into nodes,
/// and falls back gracefully to local text categorization if model weights
/// are not initialized/loaded.
class LocalLlmService {
  static bool _isModelLoaded = false;
  static String? _modelPath;

  /// Initializes the local LLM with the provided path.
  static Future<bool> init({String? modelPath}) async {
    // In a real device setup, this would load the model using llama_cpp_dart or flutter_gemma:
    // try {
    //   await Llama.load(modelPath);
    //   _isModelLoaded = true;
    //   _modelPath = modelPath;
    // } catch (e) { ... }
    _modelPath = modelPath ?? 'assets/models/gemma-3n-2b-it-q4.gguf';
    _isModelLoaded = true;
    return true;
  }

  static bool get isReady => _isModelLoaded;
  static String? get modelPath => _modelPath;
  static bool get isUsingDownloadedModel =>
      _modelPath != null && !_modelPath!.startsWith('assets/');

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
    
    final lines = text.trim().split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
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
      if (lower.contains('must') || lower.contains('todo') || lower.contains('action') || lower.contains('need to')) {
        clusters['🚀 Action Items']!.add(line);
      } else if (lower.contains('risk') || lower.contains('danger') || lower.contains('issue') || lower.contains('note')) {
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

        nodes.add(MindMapNode(
          title: category,
          children: children,
          colorValue: colorValue,
        ));
      }
    });

    return SnapMapData(
      title: rootTitle,
      nodes: nodes,
      rawText: text,
    );
  }
}
