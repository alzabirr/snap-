import '../models/snap_map_model.dart';
import '../themes/app_theme.dart';

class TextParserService {
  static SnapMapData parse(String text) {
    // STEP 1 — Clean & split
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return SnapMapData(title: 'Empty Idea', nodes: [], rawText: text);
    }

    // Split on line breaks and standard sentence endings
    final rawSentences = trimmedText
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Filter out sentences that have less than 3 words
    final cleanSentences = rawSentences.where((s) {
      final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      return words.length >= 3;
    }).toList();

    // STEP 2 — Root topic
    String rootTitle = 'My Thought';

    // Check for a heading line (ALL CAPS or ends with ':')
    final lines = trimmedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    bool foundHeading = false;
    if (lines.isNotEmpty) {
      final firstLine = lines.first;
      final isAllCaps =
          firstLine == firstLine.toUpperCase() &&
          RegExp(r'[A-Z]').hasMatch(firstLine);
      final endsWithColon = firstLine.endsWith(':');
      if (isAllCaps || endsWithColon) {
        rootTitle = endsWithColon
            ? firstLine.substring(0, firstLine.length - 1).trim()
            : firstLine;
        foundHeading = true;
      }
    }

    if (!foundHeading && cleanSentences.isNotEmpty) {
      rootTitle = _trimToWords(cleanSentences.first, 6);
    }

    if (cleanSentences.isEmpty) {
      return SnapMapData(
        title: rootTitle,
        nodes: [
          MindMapNode(
            title: '📌 Key Points',
            children: [MindMapNode(title: _trimToWords(trimmedText, 18))],
            colorValue: nodeColors.first.toARGB32(),
          ),
        ],
        rawText: text,
      );
    }

    // STEP 3 — Category detection
    final Map<String, List<String>> categoryGroups = {
      '🧑 People': [],
      '🎯 Goals': [],
      '⚙️ Process': [],
      '💡 Rationale': [],
      '📅 Timeline': [],
      '⚠️ Risks': [],
      '📌 Key Points': [],
    };

    // If the first sentence was used as the root title (and we didn't have a heading line),
    // we can skip it from the children lists to prevent redundancy.
    final sentencesToCategorize = (!foundHeading && cleanSentences.isNotEmpty)
        ? cleanSentences.skip(1).toList()
        : cleanSentences;

    if (sentencesToCategorize.isEmpty) {
      categoryGroups['📌 Key Points']!.add(cleanSentences.first);
    }

    for (var sentence in sentencesToCategorize) {
      final lower = sentence.toLowerCase();
      if (_matchesKeywords(lower, ['who', 'team', 'person', 'role', 'name'])) {
        categoryGroups['🧑 People']!.add(sentence);
      } else if (_matchesKeywords(lower, [
        'goal',
        'objective',
        'target',
        'aim',
      ])) {
        categoryGroups['🎯 Goals']!.add(sentence);
      } else if (_matchesKeywords(lower, [
        'how',
        'step',
        'process',
        'method',
      ])) {
        categoryGroups['⚙️ Process']!.add(sentence);
      } else if (_matchesKeywords(lower, [
        'why',
        'reason',
        'because',
        'since',
      ])) {
        categoryGroups['💡 Rationale']!.add(sentence);
      } else if (_matchesKeywords(lower, [
        'when',
        'timeline',
        'deadline',
        'by',
      ])) {
        categoryGroups['📅 Timeline']!.add(sentence);
      } else if (_matchesKeywords(lower, [
        'risk',
        'problem',
        'issue',
        'challenge',
      ])) {
        categoryGroups['⚠️ Risks']!.add(sentence);
      } else {
        categoryGroups['📌 Key Points']!.add(sentence);
      }
    }

    // STEP 4 — Build branches (limit to max 6 branches)
    var activeCategories = categoryGroups.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    // Sort descending by sentence count to prioritize more contentful branches
    activeCategories.sort((a, b) => b.value.length.compareTo(a.value.length));

    if (activeCategories.length > 6) {
      activeCategories.removeRange(6, activeCategories.length);
    }

    // Convert to list of TempChild for pairwise deduplication
    final List<_TempChild> allTempChildren = [];
    for (var entry in activeCategories) {
      final category = entry.key;
      // Max 4 per branch
      final sentences = entry.value.take(4).toList();
      for (var s in sentences) {
        allTempChildren.add(_TempChild(s, category));
      }
    }

    // STEP 5 — Deduplication
    final Set<_TempChild> toRemove = {};
    for (int i = 0; i < allTempChildren.length; i++) {
      for (int j = i + 1; j < allTempChildren.length; j++) {
        final a = allTempChildren[i];
        final b = allTempChildren[j];
        if (toRemove.contains(a) || toRemove.contains(b)) continue;
        if (_checkWordOverlap(a.text, b.text) > 0.60) {
          if (a.text.length >= b.text.length) {
            toRemove.add(b);
          } else {
            toRemove.add(a);
          }
        }
      }
    }
    allTempChildren.removeWhere((tc) => toRemove.contains(tc));

    // Group again by category
    final Map<String, List<String>> finalizedGroups = {};
    for (var tc in allTempChildren) {
      finalizedGroups.putIfAbsent(tc.category, () => []).add(tc.text);
    }

    // STEP 6 — Assign colors & Build nodes
    final List<MindMapNode> branchNodes = [];
    int colorIndex = 0;

    // Maintain category ordering for visual consistency (or sorted size)
    for (var entry in activeCategories) {
      final category = entry.key;
      final childSentences = finalizedGroups[category] ?? [];
      if (childSentences.isEmpty) continue;

      final colorValue = nodeColors[colorIndex % nodeColors.length].toARGB32();
      colorIndex++;

      final List<MindMapNode> childrenNodes = childSentences.map((text) {
        return MindMapNode(title: text, colorValue: colorValue);
      }).toList();

      branchNodes.add(
        MindMapNode(
          title: category,
          children: childrenNodes,
          colorValue: colorValue,
        ),
      );
    }

    // STEP 7 — Return SnapMapData
    return SnapMapData(title: rootTitle, nodes: branchNodes, rawText: text);
  }

  static String _trimToWords(String s, int maxWords) {
    final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= maxWords) return s;
    return '${words.take(maxWords).join(' ')}...';
  }

  static bool _matchesKeywords(String text, List<String> keywords) {
    for (var keyword in keywords) {
      // Use boundary regex to avoid partial matches (e.g. "anywhere" matching "where")
      final regex = RegExp('\\b$keyword\\b');
      if (regex.hasMatch(text)) {
        return true;
      }
    }
    return false;
  }

  static double _checkWordOverlap(String a, String b) {
    final wordsA = a
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length >= 2)
        .toSet();
    final wordsB = b
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length >= 2)
        .toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;

    final intersection = wordsA.intersection(wordsB);
    final minLength = wordsA.length < wordsB.length
        ? wordsA.length
        : wordsB.length;
    return intersection.length / minLength;
  }
}

class _TempChild {
  final String text;
  final String category;
  _TempChild(this.text, this.category);
}
