import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../services/text_parser_service.dart';
import '../themes/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/shimmer_loader.dart';
import 'home_screen.dart';
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

  final Map<String, String> _templates = {
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

    // Setup shake animation for validation failures
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 12.0, end: 0.0), weight: 1),
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
    });
  }

  void _handleSnap() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      // Trigger haptic & shake animation on validation error
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0.0);
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isParsing = true;
    });

    // Start 500ms minimum display delay for the shimmer loading state
    final Future parseTask = Future.delayed(
      const Duration(milliseconds: 650),
      () {
        return TextParserService.parse(text);
      },
    );

    final parsedData = await parseTask;

    if (mounted) {
      if (parsedData.nodes.isEmpty) {
        setState(() {
          _isParsing = false;
        });
        // Show dialog/snackbar for no nodes
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Couldn't find structure — try adding more detail",
              style: bodyStyle(color: Colors.white),
            ),
            backgroundColor: CupertinoColors.systemOrange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Save map to Hive storage via Provider
      final provider = Provider.of<MapProvider>(context, listen: false);
      await provider.saveMap(parsedData);
      provider.selectMap(parsedData);

      if (mounted) {
        setState(() {
          _isParsing = false;
        });
        // Navigate using CupertinoPageRoute
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (context) => const MindmapScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isParsing) {
      return const ShimmerLoader();
    }

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'New Snap'),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: 1,
        selectedItemColor: primary,
        unselectedItemColor: textMid,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushAndRemoveUntil(
              CupertinoPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Create a map first, then customize it from the canvas.',
                  style: bodyStyle(color: Colors.white),
                ),
                backgroundColor: primary,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        items: const [
          AdaptiveNavigationDestination(
            icon: CupertinoIcons.square_grid_2x2,
            selectedIcon: CupertinoIcons.square_grid_2x2_fill,
            label: 'Home',
          ),
          AdaptiveNavigationDestination(
            icon: CupertinoIcons.plus_circle,
            selectedIcon: CupertinoIcons.plus_circle_fill,
            label: 'New',
          ),
          AdaptiveNavigationDestination(
            icon: CupertinoIcons.settings,
            selectedIcon: CupertinoIcons.settings_solid,
            label: 'Tools',
          ),
        ],
      ),
      body: Container(
        color: bgLight,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shaker widget surrounding the text card
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: glassCard(
                  opacity: 0.75,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CupertinoTextField(
                        controller: _textController,
                        placeholder:
                            'Paste your notes, ideas, or brain dump here…',
                        minLines: 8,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        placeholderStyle: bodyStyle(
                          fontSize: 14,
                          color: textMid.withOpacity(0.7),
                        ),
                        style: bodyStyle(fontSize: 14, color: textDark),
                      ),
                      const SizedBox(height: 8),
                      // Character count
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          '$_charCount characters',
                          style: bodyStyle(fontSize: 12, color: textMid),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Chips for templates
              Text(
                'QUICK TEMPLATES',
                style: headingStyle(
                  fontSize: 12,
                  color: textMid,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _templates.keys.map((title) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _textController.text = _templates[title]!;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(nodeRadius),
                            border: Border.all(
                              color: primary.withOpacity(0.15),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            title,
                            style: bodyStyle(
                              fontSize: 13,
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // Snap It button
              CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _handleSnap,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primary, accent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Snap It ✨',
                        style: headingStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  )
                  .animate(target: _charCount > 0 ? 1.0 : 0.0)
                  .scale(
                    begin: const Offset(0.96, 0.96),
                    duration: 100.ms,
                    curve: Curves.easeOutBack,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
