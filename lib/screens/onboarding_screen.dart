import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../storage/hive_storage.dart';
import '../themes/app_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishOnboarding(BuildContext context) async {
    final storage = HiveStorage();
    await storage.setLaunched();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient matching page selection
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getBackgroundColors(_currentPage),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Safe Area for navigation
          SafeArea(
            child: Column(
              children: [
                // Top Skip bar
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                    child: _currentPage < 2
                        ? CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              'Skip',
                              style: headingStyle(fontSize: 15, color: Colors.white.withOpacity(0.85)),
                            ),
                            onPressed: () => _finishOnboarding(context),
                          )
                        : const SizedBox(height: 40),
                  ),
                ),

                // Page View
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      _buildPage(
                        title: 'Snap your thoughts',
                        subtitle: 'Paste any text, notes, or raw ideas and watch them instantly structured.',
                        painter: _BrainIllustrationPainter(),
                        animateDelay: 0.ms,
                      ),
                      _buildPage(
                        title: 'Instantly organized',
                        subtitle: 'We scan your text, identify topics, and layout an interactive node map automatically.',
                        painter: _MapIllustrationPainter(),
                        animateDelay: 100.ms,
                      ),
                      _buildPage(
                        title: 'Yours, offline, always',
                        subtitle: '100% on-device. No internet, no APIs, and absolute privacy for your notes.',
                        painter: _OfflineIllustrationPainter(),
                        animateDelay: 100.ms,
                      ),
                    ],
                  ),
                ),

                // Indicator & CTA Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Button CTA
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _currentPage == 2
                            ? SizedBox(
                                width: double.infinity,
                                key: const ValueKey('cta_start'),
                                child: CupertinoButton(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(buttonRadius),
                                  onPressed: () => _finishOnboarding(context),
                                  child: Text(
                                    'Get Started',
                                    style: headingStyle(fontSize: 16, color: accent),
                                  ),
                                ).animate().scale(begin: const Offset(0.95, 0.95), duration: 150.ms, curve: Curves.easeOutBack),
                              )
                            : SizedBox(
                                width: double.infinity,
                                key: const ValueKey('cta_next'),
                                child: CupertinoButton(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(buttonRadius),
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 500),
                                      curve: Curves.easeInOutCubic,
                                    );
                                  },
                                  child: Text(
                                    'Continue',
                                    style: headingStyle(fontSize: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getBackgroundColors(int page) {
    switch (page) {
      case 0:
        return [const Color(0xFF4F46E5), const Color(0xFF312E81)]; // Indigo theme
      case 1:
        return [const Color(0xFF7C3AED), const Color(0xFF4C1D95)]; // Violet theme
      case 2:
        return [const Color(0xFF059669), const Color(0xFF064E3B)]; // Emerald theme
      default:
        return [const Color(0xFF4F46E5), const Color(0xFF312E81)];
    }
  }

  Widget _buildPage({
    required String title,
    required String subtitle,
    required CustomPainter painter,
    required Duration animateDelay,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Painter Illustration
          SizedBox(
            width: 250,
            height: 250,
            child: CustomPaint(
              painter: painter,
            ),
          ).animate().scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack, duration: 600.ms),
          const SizedBox(height: 40),

          // Title
          Text(
            title,
            style: headingStyle(fontSize: 28, color: Colors.white),
            textAlign: TextAlign.center,
          ).animate(delay: animateDelay).fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            subtitle,
            style: bodyStyle(fontSize: 15, color: Colors.white.withOpacity(0.8), height: 1.5),
            textAlign: TextAlign.center,
          ).animate(delay: animateDelay + 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0),
        ],
      ),
    );
  }
}

// Custom Painter illustrations for onboarding pages

class _BrainIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw central brain glow
    canvas.drawCircle(center, 45, Paint()..color = Colors.white.withOpacity(0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    canvas.drawCircle(center, 30, Paint()..color = Colors.white.withOpacity(0.2));

    // Brain icon representation
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Left hemisphere
    canvas.drawArc(Rect.fromCenter(center: center - const Offset(12, 0), width: 30, height: 40), pi/2, pi, false, iconPaint);
    // Right hemisphere
    canvas.drawArc(Rect.fromCenter(center: center + const Offset(12, 0), width: 30, height: 40), -pi/2, pi, false, iconPaint);

    // Inner brain convolutions
    canvas.drawArc(Rect.fromCenter(center: center - const Offset(6, 6), width: 14, height: 14), 0, pi, false, iconPaint);
    canvas.drawArc(Rect.fromCenter(center: center + const Offset(6, 6), width: 14, height: 14), pi, pi, false, iconPaint);

    // Draw surrounding text notes floating and linking to the brain
    final linkPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final bubblePoints = [
      Offset(center.dx - 80, center.dy - 60),
      Offset(center.dx + 80, center.dy - 50),
      Offset(center.dx - 90, center.dy + 40),
      Offset(center.dx + 90, center.dy + 50),
    ];

    for (var point in bubblePoints) {
      canvas.drawLine(center, point, linkPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: point, width: 44, height: 22), const Radius.circular(6)),
        Paint()..color = Colors.white.withOpacity(0.15),
      );
      // Small mock text lines
      canvas.drawLine(point - const Offset(10, 0), point + const Offset(10, 0), Paint()..color = Colors.white.withOpacity(0.6)..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw connections
    final linkPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final branchPositions = [
      Offset(center.dx - 60, center.dy - 50),
      Offset(center.dx + 60, center.dy - 50),
      Offset(center.dx - 70, center.dy + 40),
      Offset(center.dx + 70, center.dy + 40),
    ];

    for (var pos in branchPositions) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(
          center.dx + (pos.dx - center.dx) * 0.4, center.dy,
          center.dx + (pos.dx - center.dx) * 0.4, pos.dy,
          pos.dx, pos.dy,
        );
      canvas.drawPath(path, linkPaint);
      
      // Draw sub branches
      final dirX = pos.dx > center.dx ? 1.0 : -1.0;
      final sub1 = Offset(pos.dx + dirX * 30, pos.dy - 20);
      final sub2 = Offset(pos.dx + dirX * 30, pos.dy + 20);
      canvas.drawLine(pos, sub1, linkPaint);
      canvas.drawLine(pos, sub2, linkPaint);
      canvas.drawCircle(sub1, 5, Paint()..color = Colors.white.withOpacity(0.8));
      canvas.drawCircle(sub2, 5, Paint()..color = Colors.white.withOpacity(0.8));

      // Draw branch nodes
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: 48, height: 20), const Radius.circular(6)),
        Paint()..color = Colors.white,
      );
    }

    // Draw central root node
    canvas.drawCircle(center, 22, Paint()..color = Colors.white);
    canvas.drawCircle(center, 18, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OfflineIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw globe/shield grid lines in background
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 75, bgPaint);
    canvas.drawCircle(center, 50, bgPaint);
    canvas.drawLine(center - const Offset(80, 0), center + const Offset(80, 0), bgPaint);
    canvas.drawLine(center - const Offset(0, 80), center + const Offset(0, 80), bgPaint);

    // Draw Shield
    final shieldPath = Path();
    shieldPath.moveTo(center.dx, center.dy - 40);
    shieldPath.quadraticBezierTo(center.dx + 30, center.dy - 40, center.dx + 30, center.dy - 10);
    shieldPath.quadraticBezierTo(center.dx + 30, center.dy + 20, center.dx, center.dy + 40);
    shieldPath.quadraticBezierTo(center.dx - 30, center.dy + 20, center.dx - 30, center.dy - 10);
    shieldPath.quadraticBezierTo(center.dx - 30, center.dy - 40, center.dx, center.dy - 40);
    shieldPath.close();

    canvas.drawPath(shieldPath, Paint()..color = Colors.white.withOpacity(0.15));
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    // Draw Lock body & shackle inside shield
    final lockCenter = center - const Offset(0, 5);
    final lockPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: lockCenter + const Offset(0, 10), width: 22, height: 16), const Radius.circular(3)),
      lockPaint,
    );
    
    final shacklePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawArc(
      Rect.fromCenter(center: lockCenter + const Offset(0, 2), width: 14, height: 14),
      pi,
      pi,
      false,
      shacklePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
