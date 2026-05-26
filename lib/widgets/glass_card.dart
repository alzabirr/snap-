import 'dart:ui';
import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

Widget glassCard({
  required Widget child,
  double opacity = 0.15,
  EdgeInsets? padding,
  BorderRadius? borderRadius,
}) {
  final radius = borderRadius ?? BorderRadius.circular(cardRadius);
  return ClipRRect(
    borderRadius: radius,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: child,
      ),
    ),
  );
}
