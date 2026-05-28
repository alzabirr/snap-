import '../../models/snap_map_model.dart';
import '../../services/local_llm_service.dart';

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
  static Future<List<Flashcard>> generateFromMapsWithLlm(
    List<SnapMapData> maps,
  ) async {
    final cards = <Flashcard>[];
    for (final map in maps) {
      try {
        final generated = await LocalLlmService.generateFlashcardsFromMap(map);
        cards.addAll(
          generated.map(
            (card) => Flashcard(
              question: card['question'] ?? '',
              answer: card['answer'] ?? '',
              sourceTitle: map.title,
            ),
          ),
        );
      } catch (_) {
        cards.addAll(generateFromMaps([map]));
      }
    }
    return cards
        .where((card) => card.question.isNotEmpty && card.answer.isNotEmpty)
        .toList();
  }

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
