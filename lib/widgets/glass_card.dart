import 'package:flutter/material.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import '../themes/app_theme.dart';

Widget glassCard({
  required Widget child,
  double opacity = 0.15,
  EdgeInsets? padding,
  BorderRadius? borderRadius,
}) {
  final radius = borderRadius ?? BorderRadius.circular(cardRadius);
  return GlassContainer(
    blur: 24,
    opacity: opacity,
    color: Colors.white.withOpacity(opacity),
    borderRadius: radius,
    border: Border.all(
      color: Colors.white.withOpacity(0.35),
      width: 1.2,
    ),
    shadowColor: Colors.black.withOpacity(0.08),
    child: padding != null
        ? Padding(
            padding: padding,
            child: child,
          )
        : child,
  );
}
