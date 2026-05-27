import 'dart:math';
import 'package:flutter/material.dart';
import '../models/snap_map_model.dart';
import '../models/snap_settings.dart';
import '../themes/app_theme.dart';

class MindMapLayoutHelper {
  static Map<String, Offset> getPositions(
    SnapMapData data,
    SnapMapSettings settings, {
    double floatOffset = 0.0,
  }) {
    final Map<String, Offset> positions = {};
    
    // Choose root base position
    final Offset rootPos = settings.layout == 'horizontal'
        ? const Offset(300, 1500)
        : (settings.layout == 'tree' || settings.layout == 'vertical'
            ? const Offset(1500, 300)
            : const Offset(1500, 1500));

    positions['root'] = rootPos;

    final branchCount = data.nodes.length;
    for (int i = 0; i < branchCount; i++) {
      final branch = data.nodes[i];
      Offset branchPos;

      if (branch.dx != 0 || branch.dy != 0) {
        branchPos = Offset(branch.dx, branch.dy);
      } else {
        switch (settings.layout) {
          case 'radial':
            final double angle = (2 * pi / branchCount) * i;
            branchPos = rootPos + Offset(cos(angle) * 320, sin(angle) * 320);
            break;
          case 'tree':
            final double startX = rootPos.dx - (branchCount - 1) * 180;
            branchPos = Offset(startX + i * 360, rootPos.dy + 250);
            break;
          case 'horizontal':
            final double startY = rootPos.dy - (branchCount - 1) * 160;
            branchPos = Offset(rootPos.dx + 350, startY + i * 320);
            break;
          case 'vertical':
            final double startX = rootPos.dx - (branchCount - 1) * 220;
            branchPos = Offset(startX + i * 440, rootPos.dy + 350);
            break;
          default:
            branchPos = rootPos + Offset(150.0 * (i + 1), 150.0 * (i + 1));
        }

        // Apply Float effect (do not apply if manual positions exist)
        branchPos += Offset(0, sin(floatOffset + i) * 2.5);
      }

      positions[branch.id] = branchPos;

      // Children layout
      final childCount = branch.children.length;
      if (branch.isExpanded) {
        for (int j = 0; j < childCount; j++) {
          final child = branch.children[j];
          Offset childPos;

          if (child.dx != 0 || child.dy != 0) {
            childPos = Offset(child.dx, child.dy);
          } else {
            switch (settings.layout) {
              case 'radial':
                final double branchAngle = (2 * pi / branchCount) * i;
                final double childAngle = branchAngle +
                    (j - (childCount - 1) / 2) * (18 * pi / 180);
                childPos = rootPos + Offset(cos(childAngle) * 540, sin(childAngle) * 540);
                break;
              case 'tree':
                // Stack vertically below the branch node
                childPos = Offset(branchPos.dx, branchPos.dy + 120 * (j + 1));
                break;
              case 'horizontal':
                final double spacing = settings.isCompact ? 60 : 90;
                childPos = Offset(
                  branchPos.dx + 260,
                  branchPos.dy + (j - (childCount - 1) / 2) * spacing,
                );
                break;
              case 'vertical':
                // Stack horizontally below the branch node
                childPos = Offset(
                  branchPos.dx + (j - (childCount - 1) / 2) * 160,
                  branchPos.dy + 180,
                );
                break;
              default:
                childPos = branchPos + Offset(120.0 * (j + 1), 120.0 * (j + 1));
            }

            // Apply Float effect
            childPos += Offset(0, sin(floatOffset + i + j) * 2.5);
          }

          positions[child.id] = childPos;
        }
      }
    }

    return positions;
  }
}

class MindMapPainter extends CustomPainter {
  final SnapMapData data;
  final SnapMapSettings settings;
  final double floatOffset;
  final String? revealBranchId;
  final double revealProgress;

  MindMapPainter({
    required this.data,
    required this.settings,
    required this.floatOffset,
    this.revealBranchId,
    this.revealProgress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Get calculated positions
    final positions = MindMapLayoutHelper.getPositions(data, settings, floatOffset: floatOffset);
    final Offset? rootPos = positions['root'];
    if (rootPos == null) return;

    // Dimensions
    const double rootRadius = 55.0;
    const double branchWidth = 130.0;
    const double branchHeight = 46.0;
    const double childWidth = 110.0;
    const double childHeight = 36.0;
    const Color mapNodeColor = primary;

    // 2. Render Bezier Connector Lines
    for (int i = 0; i < data.nodes.length; i++) {
      final branch = data.nodes[i];
      final branchPos = positions[branch.id];
      if (branchPos == null) continue;

      // Draw connection from Root to Branch
      _drawBezierConnection(canvas, rootPos, branchPos, mapNodeColor, settings.branchThickness);

      // Draw connection from Branch to Children
      if (branch.isExpanded) {
        for (var child in branch.children) {
          final childPos = positions[child.id];
          if (childPos == null) continue;
          final progress = branch.id == revealBranchId ? revealProgress : 1.0;
          if (progress <= 0) continue;
          // Connect child to branch
          _drawBezierConnection(
            canvas,
            branchPos,
            Offset.lerp(branchPos, childPos, progress)!,
            mapNodeColor.withOpacity(0.9 * progress),
            settings.branchThickness * 0.8,
          );
        }
      }
    }

    // 3. Render Root Node
    final rootRect = Rect.fromCircle(center: rootPos, radius: rootRadius);
    final rootPaint = Paint()..color = mapNodeColor;

    // Draw shadow
    canvas.drawCircle(rootPos + const Offset(0, 4), rootRadius, Paint()..color = const Color(0x1A000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(rootPos, rootRadius, rootPaint);

    // Root label
    _drawNodeText(
      canvas,
      rootPos,
      data.title,
      headingStyle(fontSize: settings.textSize + 2, color: Colors.white, fontWeight: FontWeight.bold),
      rootRadius * 2 - 16,
    );

    // 4. Render Branch and Child Nodes
    for (int i = 0; i < data.nodes.length; i++) {
      final branch = data.nodes[i];
      final branchPos = positions[branch.id];
      if (branchPos == null) continue;

      // Draw branch node shape
      final branchRect = Rect.fromCenter(center: branchPos, width: branchWidth, height: branchHeight);
      final branchRRect = RRect.fromRectAndRadius(branchRect, const Radius.circular(12));
      final branchPaint = Paint()..color = mapNodeColor;

      // Draw shadow
      canvas.drawRRect(
        branchRRect.shift(const Offset(0, 3)),
        Paint()..color = const Color(0x1F000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRRect(branchRRect, branchPaint);

      // Branch Label
      _drawNodeText(
        canvas,
        branchPos,
        branch.title,
        headingStyle(fontSize: settings.textSize, color: Colors.white, fontWeight: FontWeight.w600),
        branchWidth - 12,
      );

      // Draw branch collapse/expand indicator dot if it has children
      if (branch.children.isNotEmpty) {
        final indicatorPos = branchPos + Offset(branchWidth / 2 + 18, 0);
        canvas.drawCircle(
          indicatorPos,
          11,
          Paint()..color = mapNodeColor.withOpacity(0.88),
        );
        _drawNodeText(
          canvas,
          indicatorPos,
          branch.isExpanded ? '<' : '>',
          headingStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          18,
        );
      }

      // Draw child nodes
      if (branch.isExpanded) {
        for (var child in branch.children) {
          final childPos = positions[child.id];
          if (childPos == null) continue;
          final progress = branch.id == revealBranchId ? revealProgress : 1.0;
          if (progress <= 0) continue;
          final animatedPos = Offset.lerp(branchPos, childPos, progress)!;

          canvas.save();
          canvas.translate(animatedPos.dx, animatedPos.dy);
          canvas.scale(0.86 + (0.14 * progress));
          canvas.translate(-animatedPos.dx, -animatedPos.dy);

          final childRect = Rect.fromCenter(center: animatedPos, width: childWidth, height: childHeight);
          final childRRect = RRect.fromRectAndRadius(childRect, const Radius.circular(18)); // pill shape
          
          // solid/opaque fill depending on theme readability
          final isDarkPalette = settings.themeName == 'Mono' || settings.themeName == 'Candy';
          final childPaint = Paint()
            ..color = mapNodeColor.withOpacity(progress);

          // Draw shadow
          canvas.drawRRect(
            childRRect.shift(const Offset(0, 2)),
            Paint()
              ..color = Color.fromRGBO(0, 0, 0, 0.08 * progress)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
          canvas.drawRRect(childRRect, childPaint);

          // Child Label
          _drawNodeText(
            canvas,
            animatedPos,
            child.title,
            bodyStyle(
              fontSize: settings.textSize - 2,
              color: (isDarkPalette ? textDark : Colors.white).withOpacity(progress.clamp(0.35, 1)),
              fontWeight: FontWeight.w500,
            ),
            childWidth - 16,
          );
          canvas.restore();
        }
      }
    }
  }

  void _drawBezierConnection(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double strokeWidth,
  ) {
    final path = Path();
    path.moveTo(start.dx, start.dy);

    // Compute cubic control points
    final double dx = end.dx - start.dx;
    
    // Draw S-curves horizontally or vertically depending on orientation
    final Offset cp1 = start + Offset(dx * 0.4, 0);
    final Offset cp2 = end - Offset(dx * 0.4, 0);

    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withOpacity(0.55)
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  void _drawNodeText(
    Canvas canvas,
    Offset center,
    String text,
    TextStyle style,
    double maxWidth,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: maxWidth);
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant MindMapPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.settings != settings ||
        oldDelegate.floatOffset != floatOffset ||
        oldDelegate.revealBranchId != revealBranchId ||
        oldDelegate.revealProgress != revealProgress;
  }
}
