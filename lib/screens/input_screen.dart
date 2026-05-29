import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, BoxShadow;
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/snap_map_model.dart';
import '../providers/map_provider.dart';
import '../services/local_llm_service.dart';
import '../services/local_model_service.dart';
import '../services/text_parser_service.dart';
import '../themes/app_theme.dart';
import '../widgets/shimmer_loader.dart';
import 'mindmap_screen.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _ModePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModePill({
    required this.icon,
    required this.label,
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
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? Colors.white : const Color(0xFF1C1C1E))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDarkMode ? const Color(0xFF121212) : Colors.white)
                  : textMid,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bodyStyle(
                  fontSize: 13,
                  color: isSelected
                      ? (isDarkMode ? const Color(0xFF121212) : Colors.white)
                      : textMid,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TextButtonLike extends StatelessWidget {
  final String label;
  final bool isVisible;
  final VoidCallback onTap;

  const TextButtonLike({
    super.key,
    required this.label,
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        onPressed: isVisible ? onTap : null,
        child: Text(
          label,
          style: bodyStyle(
            fontSize: 12,
            color: const Color(0xFFFF3B30),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InputScreenState extends State<InputScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isParsing = false;
  bool _useLocalAI = true; // Enabled by default for Local local AI processing
  bool _hasModel = false;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    LocalModelService.downloadProgress.addListener(_handleModelStateChanged);
    LocalModelService.isDownloading.addListener(_handleModelStateChanged);
    _loadModelState();

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

  void _loadModelState() async {
    final hasModel = await LocalModelService.hasDownloadedModel();
    if (!mounted) return;
    setState(() => _hasModel = hasModel);
  }

  void _handleModelStateChanged() {
    _loadModelState();
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    LocalModelService.downloadProgress.removeListener(_handleModelStateChanged);
    LocalModelService.isDownloading.removeListener(_handleModelStateChanged);
    _textController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _charCount = _textController.text.length;
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

    if (_useLocalAI && !_hasModel) {
      HapticFeedback.vibrate();
      _showToast('Local AI model is still downloading in Settings.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isParsing = true;
    });

    try {
      SnapMapData parsedData;
      if (_useLocalAI) {
        parsedData = await LocalLlmService.generateMindMapFromText(text);
      } else {
        parsedData = await Future.delayed(
          const Duration(milliseconds: 650),
          () => TextParserService.parse(text),
        );
      }

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
      // Fallback to text parsing
      try {
        final parsedData = TextParserService.parse(text);
        if (!mounted) return;
        final provider = Provider.of<MapProvider>(context, listen: false);
        await provider.saveMap(parsedData);
        provider.selectMap(parsedData);
        if (mounted) {
          setState(() => _isParsing = false);
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (context) => const MindmapScreen()),
          );
        }
      } catch (fallbackError) {
        if (!mounted) return;
        setState(() => _isParsing = false);
        _showToast('Could not structure this snap. Please try again.');
      }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.chevron_left,
                      color: textDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'New Snap',
                    style: headingStyle(
                      fontSize: 18,
                      color: textDark,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: textDark.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      '${(_charCount / 5).round()} words',
                      style: bodyStyle(
                        fontSize: 12,
                        color: textMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                          'Create a new mind map',
                          style: headingStyle(
                            fontSize: 26,
                            color: textDark,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 4),
                    Text(
                      'Add your notes and let Snap organize the important parts.',
                      style: bodyStyle(
                        fontSize: 13,
                        color: textMid,
                        height: 1.4,
                      ),
                    ).animate().fadeIn(delay: 80.ms, duration: 300.ms),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: textDark.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModePill(
                              icon: CupertinoIcons.sparkles,
                              label: 'AI map',
                              isSelected: _useLocalAI,
                              onTap: () => setState(() => _useLocalAI = true),
                            ),
                          ),
                          Expanded(
                            child: _ModePill(
                              icon: CupertinoIcons.text_alignleft,
                              label: 'Fast parse',
                              isSelected: !_useLocalAI,
                              onTap: () => setState(() => _useLocalAI = false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _charCount > 0
                                ? primary.withValues(alpha: 0.22)
                                : textDark.withValues(alpha: 0.07),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 22,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CupertinoTextField(
                              controller: _textController,
                              placeholder: 'Paste your notes here...',
                              minLines: 11,
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  '$_charCount characters',
                                  style: bodyStyle(
                                    fontSize: 12,
                                    color: textMid,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                TextButtonLike(
                                  label: 'Clear',
                                  isVisible: _charCount > 0,
                                  onTap: () {
                                    _textController.clear();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
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
                        borderRadius: BorderRadius.circular(22),
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
                            'Create Mind Map',
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
