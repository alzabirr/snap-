import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/app_theme.dart';
import 'glass_card.dart';

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
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Center(
        child: glassCard(
          opacity: 0.22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          borderRadius: BorderRadius.circular(30),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavItem(
                icon: CupertinoIcons.square_grid_2x2,
                label: 'Home',
                isSelected: selectedIndex == 0,
                onTap: onHomeTap,
              ),
              const _NavDivider(),
              _NavItem(
                icon: CupertinoIcons.plus_circle,
                label: 'New',
                isSelected: selectedIndex == 1,
                onTap: onNewTap,
              ),
              const _NavDivider(),
              _NavItem(
                icon: CupertinoIcons.settings,
                label: 'Tools',
                isSelected: selectedIndex == 2,
                onTap: onSettingsTap,
              ),
            ],
          ),
        ),
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
    final color = isSelected ? primary : textDark;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: SizedBox(
        width: 48,
        height: 46,
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
                fontSize: 10,
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

class _NavDivider extends StatelessWidget {
  const _NavDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.2,
      height: 24,
      color: Colors.white.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
