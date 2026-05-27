import '../../models/snap_map_model.dart';

class Flashcard {
  final String question;
  final String answer;
  final String sourceTitle;

  const Flashcard({
    required this.question,
    required this.answer,
    required this.sourceTitle,
  });
}

class FlashcardsService {
  static List<Flashcard> generateFromMaps(List<SnapMapData> maps) {
    final cards = <Flashcard>[];
    for (final map in maps) {
      for (final branch in map.nodes) {
        if (branch.children.isEmpty) continue;
        cards.add(
          Flashcard(
            question: 'What are the key points in ${branch.title}?',
            answer: branch.children.map((child) => child.title).join('\n'),
            sourceTitle: map.title,
          ),
        );
        for (final child in branch.children.take(4)) {
          cards.add(
            Flashcard(
              question: 'Explain: ${child.title}',
              answer: 'Source: ${branch.title}\nMap: ${map.title}',
              sourceTitle: map.title,
            ),
          );
        }
      }
    }
    return cards;
  }
}
