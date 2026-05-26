import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, BoxShadow;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../services/text_parser_service.dart';
import '../themes/app_theme.dart';
import '../widgets/shimmer_loader.dart';
import 'mindmap_screen.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isParsing = false;
  int _charCount = 0;
  String? _selectedTemplate;

  final List<Map<String, String>> _templates = [
    {'emoji': '📝', 'label': 'Meeting', 'key': '📝 Meeting Notes'},
    {'emoji': '💡', 'label': 'Brainstorm', 'key': '💡 Brainstorm'},
    {'emoji': '📚', 'label': 'Study', 'key': '📚 Study Notes'},
    {'emoji': '🚀', 'label': 'Product', 'key': '🚀 Product Plan'},
  ];

  final Map<String, String> _templateContents = {
    '📝 Meeting Notes':
        'PROJECT STATUS REVIEW MEETING:\nOur main goal is to finalize the UI redesign by Friday. Who is responsible? Sarah will handle the Figma mockups, and James will lead the backend team. For our timeline, we must deploy the staging environment by Thursday. How will we execute this? We will follow a two-step review process. However, the risk is a potential delay in API integration.',
    '💡 Brainstorm':
        'NEW APP IDEA - SNAP MIND MAP:\nOur team wants to build a local mind-mapping tool. The goal is to let users paste raw text and immediately view structure. Why are we doing this? Users need to organize unstructured thoughts with 100% offline privacy. For process, we will parse text on-device using a fast keyword matching algorithm. Our risk is handling extremely long sentences which may clutter the node canvas.',
    '📚 Study Notes':
        'CELLULAR MITOSIS STUDY SHEET:\nGoals: We want to study the phases of cell division. The timeline of mitosis occurs in four sequential stages: prophase, metaphase, anaphase, and telophase. Process: Chromatids line up along the equator and pull apart. Person: This mechanism was first detailed by Walther Flemming in 1882. Why is this critical? Mitosis ensures that each daughter cell receives an exact copy of the DNA.',
    '🚀 Product Plan':
        'OFFLINE MINDMAP PRODUCT LAUNCH PLAN:\nOur team will launch the app on iOS next month. The target is to acquire 5,000 active users in the first week. Rationale: High demand for private, offline-first productivity applications. How to succeed? We will promote the app on product discovery platforms and local communities. The risk is limited visibility because we don\'t have a marketing budget.',
  };

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _charCount = _textController.text.length;
      _selectedTemplate = null;
    });
  }

  void _showToast(String message) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(message, style: bodyStyle(color: textDark)),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _handleSnap() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0.0);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isParsing = true;
    });

    try {
      final parsedData = await Future.delayed(
        const Duration(milliseconds: 650),
        () => TextParserService.parse(text),
      );

      if (!mounted) return;

      if (parsedData.nodes.isEmpty) {
        setState(() => _isParsing = false);
        _showToast("Couldn't find structure — try adding more detail");
        return;
      }

      final provider = Provider.of<MapProvider>(context, listen: false);
      await provider.saveMap(parsedData);
      provider.selectMap(parsedData);

      if (mounted) {
        setState(() => _isParsing = false);
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (context) => const MindmapScreen()),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isParsing = false);
      _showToast('Could not structure this snap. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isParsing) return const ShimmerLoader();

    return CupertinoPageScaffold(
      backgroundColor: bgLight,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Custom Top Bar ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.chevron_left,
                      color: textDark,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'New Snap',
                    style: headingStyle(
                      fontSize: 17,
                      color: textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Word count badge
                  AnimatedOpacity(
                    opacity: _charCount > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_charCount',
                        style: bodyStyle(
                          fontSize: 12,
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content ────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Large heading ─────────────────────────
                    Text(
                          'What\'s on your mind?',
                          style: headingStyle(
                            fontSize: 28,
                            color: textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 4),
                    Text(
                      'Paste text, notes or a brain dump — we\'ll structure it.',
                      style: bodyStyle(
                        fontSize: 13,
                        color: textMid,
                        height: 1.4,
                      ),
                    ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
                    const SizedBox(height: 20),

                    // ── Text Input Area ───────────────────────
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _charCount > 0
                                ? primary.withValues(alpha: 0.25)
                                : textDark.withValues(alpha: 0.07),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CupertinoTextField(
                              controller: _textController,
                              placeholder:
                                  'Start typing or paste your text here…',
                              minLines: 9,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              keyboardAppearance: Brightness.light,
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                              ),
                              placeholderStyle: bodyStyle(
                                fontSize: 15,
                                color: textMid.withValues(alpha: 0.7),
                                height: 1.5,
                              ),
                              style: bodyStyle(
                                fontSize: 15,
                                color: textDark,
                                height: 1.6,
                              ),
                            ),
                            if (_charCount > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_charCount characters · ${(_charCount / 5).round()} words',
                                    style: bodyStyle(
                                      fontSize: 11,
                                      color: textMid,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      _textController.clear();
                                      setState(() {
                                        _selectedTemplate = null;
                                      });
                                    },
                                    child: Text(
                                      'Clear',
                                      style: bodyStyle(
                                        fontSize: 11,
                                        color: const Color(0xFFFF3B30),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
                    const SizedBox(height: 28),

                    // ── Templates ─────────────────────────────
                    Row(
                      children: [
                        Text(
                          'QUICK TEMPLATES',
                          style: bodyStyle(
                            fontSize: 11,
                            color: textMid,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: textDark.withValues(alpha: 0.06),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Template grid 2x2
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.5,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _templates.map((t) {
                        final key = t['key']!;
                        final isSelected = _selectedTemplate == key;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _selectedTemplate = key;
                            });
                            _textController.text = _templateContents[key]!;
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primary.withValues(alpha: 0.08)
                                  : const Color(0xFFF7F7F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? primary.withValues(alpha: 0.4)
                                    : textDark.withValues(alpha: 0.07),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  t['emoji']!,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t['label']!,
                                  style: bodyStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? primary
                                        : textDark.withValues(alpha: 0.75),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Sticky Snap It Button ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child:
                  GestureDetector(
                    onTap: _handleSnap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 58,
                      decoration: BoxDecoration(
                        color: _charCount > 0
                            ? primary
                            : textDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: _charCount > 0
                            ? [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            color: _charCount > 0 ? Colors.white : textMid,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Snap It',
                            style: headingStyle(
                              fontSize: 17,
                              color: _charCount > 0 ? Colors.white : textMid,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().slideY(
                    begin: 0.3,
                    end: 0,
                    delay: 100.ms,
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
