import '../models/snap_map_model.dart';
import '../themes/app_theme.dart';

class AiMindMapService {
  static SnapMapData generateNotebookStyleMap(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return SnapMapData(title: 'Empty Idea', nodes: [], rawText: text);
    }

    final sentences = trimmed
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.split(RegExp(r'\s+')).length >= 3)
        .toList();

    final lines = trimmed
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final title = _extractTitle(lines, sentences);
    final groups = <String, List<String>>{};

    for (final sentence in sentences) {
      final branch = _inferBranchTitle(sentence);
      groups.putIfAbsent(branch, () => <String>[]).add(sentence);
    }

    if (sentences.isNotEmpty) {
      groups
          .putIfAbsent(title, () => <String>[])
          .insertAll(0, _buildSummaryPoints(title, sentences).take(2));
    }

    final nodes = <MindMapNode>[];
    var colorIndex = 0;
    for (final entry in groups.entries) {
      final items = _dedupe(entry.value).take(5).toList();
      if (items.isEmpty) continue;

      final colorValue = nodeColors[colorIndex % nodeColors.length].toARGB32();
      colorIndex++;
      nodes.add(
        MindMapNode(
          title: entry.key,
          colorValue: colorValue,
          children: items
              .map(
                (item) =>
                    MindMapNode(title: _trim(item, 92), colorValue: colorValue),
              )
              .toList(),
        ),
      );
    }

    return SnapMapData(title: title, nodes: nodes, rawText: text);
  }

  static String _extractTitle(List<String> lines, List<String> sentences) {
    if (lines.isNotEmpty && lines.first.length <= 70) {
      return lines.first.replaceAll(RegExp(r'[:#*]'), '').trim();
    }
    if (sentences.isNotEmpty) {
      return _trimWords(sentences.first, 7);
    }
    return 'AI Mind Map';
  }

  static List<String> _buildSummaryPoints(
    String title,
    List<String> sentences,
  ) {
    final points = <String>[];
    points.add('Main topic: $title');
    if (sentences.isNotEmpty) {
      points.add(_trim(sentences.first, 100));
    }
    if (sentences.length > 1) {
      points.add(
        '${sentences.length} source points were organized into branches.',
      );
    }
    return points;
  }

  static String _inferBranchTitle(String sentence) {
    final clean = sentence.replaceAll(RegExp(r'[:#*]'), '').trim();
    final lower = clean.toLowerCase();
    if (_containsAny(lower, ['because', 'reason', 'therefore', 'why'])) {
      return _trimWords(clean, 3);
    }
    if (_containsAny(lower, ['compare', 'versus', ' vs ', 'difference'])) {
      return 'Comparisons';
    }
    if (_containsAny(lower, ['example', 'case', 'instance'])) {
      return 'Examples';
    }
    if (_containsAny(lower, ['risk', 'problem', 'issue', 'gap', 'challenge'])) {
      return 'Concerns';
    }
    if (_containsAny(lower, [
      'must',
      'need to',
      'todo',
      'build',
      'create',
      'fix',
    ])) {
      return 'Next Steps';
    }
    return _trimWords(clean, 3);
  }

  static bool _containsAny(String value, List<String> words) {
    return words.any(value.contains);
  }

  static List<String> _dedupe(List<String> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final key = item.toLowerCase().replaceAll(RegExp(r'\W+'), ' ').trim();
      if (seen.add(key)) result.add(item);
    }
    return result;
  }

  static String _trim(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars - 3)}...';
  }

  static String _trimWords(String value, int maxWords) {
    final words = value.split(RegExp(r'\s+'));
    if (words.length <= maxWords) return value;
    return '${words.take(maxWords).join(' ')}...';
  }
}
