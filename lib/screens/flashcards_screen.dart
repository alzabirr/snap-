import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/flashcards/flashcards_service.dart';
import '../models/snap_map_model.dart';
import '../providers/map_provider.dart';
import '../themes/app_theme.dart';

class FlashcardsScreen extends StatefulWidget {
  final String? initialMapId;

  const FlashcardsScreen({super.key, this.initialMapId});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  int _index = 0;
  bool _showAnswer = false;
  String? _selectedMapId;

  @override
  void initState() {
    super.initState();
    _selectedMapId = widget.initialMapId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MapProvider>(context, listen: false).loadMaps();
    });
  }

  void _nextCard(int cardCount) {
    HapticFeedback.lightImpact();
    setState(() {
      _showAnswer = false;
      _index = (_index + 1) % cardCount;
    });
  }

  void _selectMap(String? mapId) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMapId = mapId;
      _index = 0;
      _showAnswer = false;
    });
    Navigator.of(context).pop();
  }

  void _showMapPicker(List<SnapMapData> maps) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: textMid.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Flashcard Source',
                    textAlign: TextAlign.center,
                    style: headingStyle(
                      fontSize: 20,
                      color: textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose which mind map to study',
                    textAlign: TextAlign.center,
                    style: bodyStyle(
                      fontSize: 13,
                      color: textMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _SourceOption(
                          title: 'All mind maps',
                          subtitle: '${FlashcardsService.generateFromMaps(maps).length} cards',
                          isSelected: _selectedMapId == null,
                          onTap: () => _selectMap(null),
                        ),
                        const SizedBox(height: 10),
                        ...maps.map((map) {
                          final count =
                              FlashcardsService.generateFromMaps([map]).length;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SourceOption(
                              title: map.title,
                              subtitle: '$count cards',
                              isSelected: _selectedMapId == map.id,
                              onTap: () => _selectMap(map.id),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: bodyStyle(
                        color: textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final maps = Provider.of<MapProvider>(context).maps;
    final selectedMaps = _selectedMapId == null
        ? maps
        : maps.where((map) => map.id == _selectedMapId).toList();
    final cards = FlashcardsService.generateFromMaps(selectedMaps);
    final hasCards = cards.isNotEmpty;
    final card = hasCards ? cards[_index.clamp(0, cards.length - 1)] : null;
    final selectedMap = _selectedMapId == null
        ? null
        : maps.where((map) => map.id == _selectedMapId).toList();
    final selectedTitle = _selectedMapId == null
        ? 'All mind maps'
        : (selectedMap != null && selectedMap.isNotEmpty
              ? selectedMap.first.title
              : 'Selected map');

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.chevron_left,
                        color: textDark,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Flashcards',
                    style: headingStyle(
                      fontSize: 26,
                      color: textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (hasCards)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showMapPicker(maps),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: textDark.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.book_fill,
                          color: primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${cards.length} study cards • $selectedTitle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bodyStyle(
                              fontSize: 13,
                              color: textDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.chevron_down,
                          color: textMid,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Expanded(
                child: hasCards
                    ? GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showAnswer = !_showAnswer);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.all(0),
                          decoration: BoxDecoration(
                            color: _showAnswer ? primary : Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 30,
                                offset: Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 22,
                                right: 22,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (_showAnswer
                                            ? Colors.white
                                            : primary)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '${_index + 1}/${cards.length}',
                                    style: bodyStyle(
                                      fontSize: 12,
                                      color:
                                          _showAnswer ? Colors.white : primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: (_showAnswer
                                                ? Colors.white
                                                : primary)
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _showAnswer
                                            ? CupertinoIcons.checkmark_alt
                                            : CupertinoIcons.question,
                                        color: _showAnswer
                                            ? Colors.white
                                            : primary,
                                        size: 25,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _showAnswer ? 'Answer' : 'Question',
                                      textAlign: TextAlign.center,
                                      style: bodyStyle(
                                        fontSize: 13,
                                        color: _showAnswer
                                            ? Colors.white.withValues(
                                                alpha: 0.78,
                                              )
                                            : primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      _showAnswer
                                          ? card!.answer
                                          : card!.question,
                                      textAlign: TextAlign.center,
                                      style: headingStyle(
                                        fontSize: _showAnswer ? 21 : 25,
                                        color: _showAnswer
                                            ? Colors.white
                                            : textDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _showAnswer
                                          ? 'Tap for question'
                                          : 'Tap to reveal answer',
                                      textAlign: TextAlign.center,
                                      style: bodyStyle(
                                        color: _showAnswer
                                            ? Colors.white.withValues(
                                                alpha: 0.72,
                                              )
                                            : textMid,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      card.sourceTitle,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: bodyStyle(
                                        color: _showAnswer
                                            ? Colors.white.withValues(
                                                alpha: 0.58,
                                              )
                                            : textMid.withValues(alpha: 0.76),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          'Create a mind map first, then flashcards will appear here.',
                          textAlign: TextAlign.center,
                          style: bodyStyle(
                            color: textMid,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
              ),
              if (hasCards) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        onPressed: () =>
                            setState(() => _showAnswer = !_showAnswer),
                        child: Text(
                          _showAnswer ? 'Hide' : 'Reveal',
                          style: bodyStyle(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoButton(
                        color: primary,
                        borderRadius: BorderRadius.circular(20),
                        onPressed: () => _nextCard(cards.length),
                        child: Text(
                          'Next',
                          style: bodyStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SourceOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : textDark.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.18)
                    : primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                CupertinoIcons.rectangle_stack,
                color: isSelected ? Colors.white : primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle(
                      fontSize: 15,
                      color: isSelected ? Colors.white : textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: bodyStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.72)
                          : textMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                CupertinoIcons.checkmark_alt,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
