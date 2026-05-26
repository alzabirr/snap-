import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/glass_card.dart';
import 'input_screen.dart';
import 'mindmap_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load maps on enter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MapProvider>(context, listen: false).loadMaps();
    });
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _openInput() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (context) => const InputScreen()));
  }

  void _showToolsMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Open a map to customize themes, layout, and export.',
          style: bodyStyle(color: Colors.white),
        ),
        backgroundColor: primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MapProvider>(context);
    final maps = provider.maps;

    return AdaptiveScaffold(
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: 0,
        selectedItemColor: primary,
        unselectedItemColor: textMid,
        onTap: (index) {
          if (index == 1) {
            _openInput();
          } else if (index == 2) {
            _showToolsMessage();
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
        child: Stack(
          children: [
            // Background Gradient decoration at the top
            Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(maps.length),

                  // Content Area
                  Expanded(
                    child: provider.isLoading
                        ? const Center(
                            child: CupertinoActivityIndicator(radius: 14),
                          )
                        : maps.isEmpty
                        ? _buildEmptyState(context)
                        : _buildMapsList(context, provider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int mapCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Snap',
                      style: headingStyle(
                        fontSize: 34,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn().slideX(begin: -0.2),
                    const SizedBox(height: 4),
                    Text(
                      mapCount == 0
                          ? 'Turn notes into mind maps'
                          : '$mapCount saved mind maps',
                      style: bodyStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _openInput,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ).animate().scale(begin: const Offset(0.8, 0.8)),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.lock_shield,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Private, offline mind maps from your raw ideas.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: bodyStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floating mind map outline illustration
            SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(painter: _EmptyStatePainter()),
                )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .slideY(
                  begin: -0.05,
                  end: 0.05,
                  duration: 2500.ms,
                  curve: Curves.easeInOutSine,
                ),
            const SizedBox(height: 32),
            Text(
              'Snap your first thought',
              style: headingStyle(fontSize: 22, color: textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Paste a meeting brief, reading note, or plan to see it instantly visualised offline.',
              style: bodyStyle(fontSize: 14, color: textMid, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CupertinoButton(
              color: primary,
              borderRadius: BorderRadius.circular(buttonRadius),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (context) => const InputScreen()),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.pen, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Write Note',
                    style: headingStyle(fontSize: 15, color: Colors.white),
                  ),
                ],
              ),
            ).animate().scale(
              begin: const Offset(0.95, 0.95),
              duration: 150.ms,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapsList(BuildContext context, MapProvider provider) {
    final maps = provider.maps;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
      itemCount: maps.length,
      itemBuilder: (context, index) {
        final map = maps[index];

        return Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: Dismissible(
                key: Key(map.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed,
                    borderRadius: BorderRadius.circular(cardRadius),
                  ),
                  child: const Icon(
                    CupertinoIcons.delete_solid,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                onDismissed: (direction) async {
                  await provider.deleteMap(map.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${map.title}" deleted',
                          style: bodyStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: GestureDetector(
                  onTap: () {
                    provider.selectMap(map);
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const MindmapScreen(),
                      ),
                    );
                  },
                  child: glassCard(
                    opacity: 0.6,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Visual Mind Map indicator circle
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary, accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.flowchart,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Texts
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                map.title,
                                style: headingStyle(
                                  fontSize: 16,
                                  color: textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    _formatDate(map.createdAt),
                                    style: bodyStyle(
                                      fontSize: 12,
                                      color: textMid,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Node count badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${map.totalNodeCount} nodes',
                                      style: bodyStyle(
                                        fontSize: 10,
                                        color: accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Color strip (6 small circles representing branch colors)
                              Row(
                                children: List.generate(6, (i) {
                                  final color = i < map.nodes.length
                                      ? map.nodes[i].color
                                      : Colors.grey.withOpacity(0.2);
                                  return Container(
                                    margin: const EdgeInsets.only(right: 4.0),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),

                        const Icon(
                          CupertinoIcons.chevron_forward,
                          color: textMid,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .animate(delay: (index * 50).ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.1, end: 0);
      },
    );
  }
}

// Custom Painter for empty state illustration
class _EmptyStatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = primary.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    // Large background glow
    canvas.drawCircle(center, 50, paint);

    // Core nodes link lines
    final linePaint = Paint()
      ..color = primary.withOpacity(0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final targets = [
      Offset(center.dx - 45, center.dy - 40),
      Offset(center.dx + 45, center.dy - 40),
      Offset(center.dx - 55, center.dy + 35),
      Offset(center.dx + 55, center.dy + 35),
    ];

    for (var target in targets) {
      canvas.drawLine(center, target, linePaint);
      canvas.drawCircle(target, 8, Paint()..color = accent.withOpacity(0.2));
      canvas.drawCircle(target, 4, Paint()..color = accent);
    }

    // Center node
    canvas.drawCircle(center, 16, Paint()..color = primary.withOpacity(0.2));
    canvas.drawCircle(center, 8, Paint()..color = primary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
