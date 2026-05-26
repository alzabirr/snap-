import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

class ShimmerLoader extends StatefulWidget {
  const ShimmerLoader({super.key});

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gradientPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _gradientPosition = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: bgLight,
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest.shortestSide.clamp(
                    240.0,
                    400.0,
                  );
                  return Center(
                    child: CustomPaint(
                      size: Size.square(size),
                      painter: _ShimmerPainter(
                        gradientOffset: _gradientPosition.value,
                      ),
                    ),
                  );
                },
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Structuring your thoughts...',
                          textAlign: TextAlign.center,
                          style: headingStyle(fontSize: 18, color: textDark),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Formatting, categorizing, and connecting nodes offline',
                          textAlign: TextAlign.center,
                          style: bodyStyle(fontSize: 13, color: textMid),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double gradientOffset;

  _ShimmerPainter({required this.gradientOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Create a horizontal shimmer linear gradient shader
    final shader = LinearGradient(
      colors: const [
        Color(0xFFE2E8F0),
        Color(0xFFCBD5E1),
        Color(0xFFF1F5F9),
        Color(0xFFCBD5E1),
        Color(0xFFE2E8F0),
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      begin: Alignment(gradientOffset - 1.0, -0.2),
      end: Alignment(gradientOffset, 0.2),
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    paint.shader = shader;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = shader;

    // Branches offsets
    final branches = [
      Offset(center.dx - 120, center.dy - 100),
      Offset(center.dx + 120, center.dy - 100),
      Offset(center.dx - 140, center.dy + 40),
      Offset(center.dx + 140, center.dy + 40),
      Offset(center.dx, center.dy - 140),
      Offset(center.dx, center.dy + 140),
    ];

    // Draw connector lines
    for (var branch in branches) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(
          center.dx + (branch.dx - center.dx) * 0.5,
          center.dy,
          center.dx + (branch.dx - center.dx) * 0.5,
          branch.dy,
          branch.dx,
          branch.dy,
        );
      canvas.drawPath(path, linePaint);
    }

    // Draw branch children node connectors
    for (int i = 0; i < branches.length; i++) {
      final branch = branches[i];
      final direction = branch.dx > center.dx ? 1.0 : -1.0;
      final child1 = Offset(branch.dx + direction * 40, branch.dy - 30);
      final child2 = Offset(branch.dx + direction * 40, branch.dy + 30);

      final path1 = Path()
        ..moveTo(branch.dx, branch.dy)
        ..quadraticBezierTo(
          branch.dx + direction * 20,
          branch.dy,
          child1.dx,
          child1.dy,
        );
      final path2 = Path()
        ..moveTo(branch.dx, branch.dy)
        ..quadraticBezierTo(
          branch.dx + direction * 20,
          branch.dy,
          child2.dx,
          child2.dy,
        );

      canvas.drawPath(path1, linePaint);
      canvas.drawPath(path2, linePaint);

      // Draw children circles
      canvas.drawCircle(child1, 6, paint);
      canvas.drawCircle(child2, 6, paint);
    }

    // Draw branch nodes (RRects)
    for (var branch in branches) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: branch, width: 70, height: 26),
          const Radius.circular(8),
        ),
        paint,
      );
    }

    // Draw root node (large circle)
    canvas.drawCircle(center, 40, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) {
    return oldDelegate.gradientOffset != gradientOffset;
  }
}
