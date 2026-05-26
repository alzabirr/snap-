import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../themes/app_theme.dart';

class AppNavBar extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onNewTap;
  final VoidCallback onSettingsTap;

  const AppNavBar({
    super.key,
    required this.selectedIndex,
    required this.onHomeTap,
    required this.onNewTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A312E81),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: CupertinoIcons.square_grid_2x2,
                    label: 'Home',
                    isSelected: selectedIndex == 0,
                    onTap: onHomeTap,
                  ),
                ),
                _NewSnapButton(onTap: onNewTap),
                Expanded(
                  child: _NavItem(
                    icon: CupertinoIcons.slider_horizontal_3,
                    label: 'Tools',
                    isSelected: selectedIndex == 2,
                    onTap: onSettingsTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewSnapButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NewSnapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 68,
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primary, accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 26),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? primary : textMid;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 50,
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle(
                fontSize: 11,
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
