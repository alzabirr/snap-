import 'package:flutter/material.dart';
import 'dart:ui';
import '../themes/app_theme.dart';

class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgLight,
      child: child,
    );
  }
}
