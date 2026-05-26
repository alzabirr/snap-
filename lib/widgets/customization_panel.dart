import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../themes/app_theme.dart';

class CustomizationPanel extends StatelessWidget {
  const CustomizationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.2,
      maxChildSize: 0.65,
      builder: (BuildContext context, ScrollController scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: surface.withOpacity(0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border.all(
                  color: textDark.withOpacity(0.08),
                  width: 1.5,
                ),
              ),
              child: Consumer<MapProvider>(
                builder: (context, provider, child) {
                  final settings = provider.settings;
                  
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: textMid.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Customize Mind Map',
                        style: headingStyle(fontSize: 18, color: textDark),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Layout Selection
                      Text(
                        'LAYOUT',
                        style: headingStyle(fontSize: 12, color: textMid, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      CupertinoSlidingSegmentedControl<String>(
                        groupValue: settings.layout,
                        children: {
                          'radial': Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Radial', style: bodyStyle(fontSize: 13, color: textDark)),
                          ),
                          'tree': Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Tree', style: bodyStyle(fontSize: 13, color: textDark)),
                          ),
                          'horizontal': Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Horiz', style: bodyStyle(fontSize: 13, color: textDark)),
                          ),
                          'vertical': Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Vert', style: bodyStyle(fontSize: 13, color: textDark)),
                          ),
                        },
                        onValueChanged: (val) {
                          if (val != null) {
                            provider.updateSetting(layout: val);
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // Theme Selection (GridView 2 rows, horizontal scroll)
                      Text(
                        'COLOR THEME',
                        style: headingStyle(fontSize: 12, color: textMid, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 90,
                        child: GridView.builder(
                          scrollDirection: Axis.horizontal,
                          controller: ScrollController(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.35,
                          ),
                          itemCount: themePalettes.keys.length,
                          itemBuilder: (context, index) {
                            final name = themePalettes.keys.elementAt(index);
                            final paletteColors = themePalettes[name]!;
                            final isSelected = settings.themeName == name;
                            
                            return GestureDetector(
                              onTap: () {
                                provider.updateSetting(themeName: name);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? textDark.withOpacity(0.1) : textDark.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? primary : textDark.withOpacity(0.08),
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: bodyStyle(
                                          fontSize: 12,
                                          color: textDark,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    // Mini Palette Preview
                                    Row(
                                      children: List.generate(
                                        3,
                                        (i) => Container(
                                          margin: const EdgeInsets.only(left: 2),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: paletteColors[i % paletteColors.length],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Text Size & Branch Width
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TEXT SIZE (${settings.textSize.toInt()}px)',
                                  style: headingStyle(fontSize: 12, color: textMid, fontWeight: FontWeight.bold),
                                ),
                                CupertinoSlider(
                                  min: 10,
                                  max: 22,
                                  value: settings.textSize,
                                  onChanged: (val) {
                                    provider.updateSetting(textSize: val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BRANCH WIDTH (${settings.branchThickness.toStringAsFixed(1)})',
                                  style: headingStyle(fontSize: 12, color: textMid, fontWeight: FontWeight.bold),
                                ),
                                CupertinoSlider(
                                  min: 1.0,
                                  max: 4.0,
                                  value: settings.branchThickness,
                                  onChanged: (val) {
                                    provider.updateSetting(branchThickness: val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Compact / Expanded Mode
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'COMPACT MODE',
                                style: headingStyle(fontSize: 12, color: textMid, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Shrinks spacing between child nodes',
                                style: bodyStyle(fontSize: 11, color: textMid),
                              ),
                            ],
                          ),
                          CupertinoSwitch(
                            value: settings.isCompact,
                            activeColor: primary,
                            onChanged: (val) {
                              provider.updateSetting(isCompact: val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Auto layout reset button
                      CupertinoButton(
                        color: accent.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(buttonRadius),
                        onPressed: () {
                          provider.resetNodePositions();
                          HapticFeedback.heavyImpact();
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.refresh_bold, size: 18),
                            const SizedBox(width: 8),
                            Text('Auto-Align Nodes', style: headingStyle(fontSize: 14, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
