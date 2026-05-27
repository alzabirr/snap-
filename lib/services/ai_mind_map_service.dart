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
    final groups = <String, List<String>>{
      'Core Summary': [],
      'Key Ideas': [],
      'People & Roles': [],
      'Timeline': [],
      'Questions': [],
      'Action Items': [],
      'Risks & Gaps': [],
    };

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      if (_containsAny(lower, ['who', 'person', 'team', 'role', 'owner', 'lead'])) {
        groups['People & Roles']!.add(sentence);
      } else if (_containsAny(lower, ['when', 'date', 'deadline', 'timeline', 'today', 'tomorrow', 'week', 'month', 'year', 'by '])) {
        groups['Timeline']!.add(sentence);
      } else if (sentence.endsWith('?') || _containsAny(lower, ['why', 'how', 'what if'])) {
        groups['Questions']!.add(sentence);
      } else if (_containsAny(lower, ['todo', 'must', 'need to', 'action', 'build', 'create', 'make', 'fix', 'launch'])) {
        groups['Action Items']!.add(sentence);
      } else if (_containsAny(lower, ['risk', 'problem', 'issue', 'gap', 'blocker', 'challenge', 'fail'])) {
        groups['Risks & Gaps']!.add(sentence);
      } else {
        groups['Key Ideas']!.add(sentence);
      }
    }

    groups['Core Summary']!.addAll(_buildSummaryPoints(title, sentences));

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
                (item) => MindMapNode(
                  title: _trim(item, 92),
                  colorValue: colorValue,
                ),
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

  static List<String> _buildSummaryPoints(String title, List<String> sentences) {
    final points = <String>[];
    points.add('Main topic: $title');
    if (sentences.isNotEmpty) {
      points.add(_trim(sentences.first, 100));
    }
    if (sentences.length > 1) {
      points.add('${sentences.length} source points were organized into branches.');
    }
    return points;
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
