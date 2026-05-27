import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/ambient_background.dart';
import 'input_screen.dart';
import 'mindmap_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Color> _cardColors = [
    const Color(0xFFD6C7FF), // Lavender
    const Color(0xFFABF680), // Lime Green
    const Color(0xFFBFEFFF), // Light Blue
    const Color(0xFFFFD1A9), // Peach
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MapProvider>(context, listen: false).loadMaps();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    return '${dt.day}th ${months[dt.month - 1]} ${dt.year}';
  }

  void _openInput() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (context) => const InputScreen()));
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (context) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MapProvider>(context);
    final maps = provider.maps;

    // Filter maps by search query
    final filteredMaps = maps.where((map) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return map.title.toLowerCase().contains(q) ||
          map.rawText.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Content area with top padding for the floating top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: provider.isLoading
                    ? const Center(
                        child: CupertinoActivityIndicator(radius: 14),
                      )
                    : filteredMaps.isEmpty
                    ? _buildEmptyState()
                    : _buildNotesGrid(filteredMaps, provider),
              ),

              // Floating Top Header (Apple-style glassmorphic)
              Positioned(
                top: 10,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: surface.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.search,
                                  color: textMid,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: _searchController,
                                    placeholder: 'Search snap',
                                    placeholderStyle: bodyStyle(
                                      color: textDark.withOpacity(0.4),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    style: bodyStyle(
                                      color: textDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    decoration: null,
                                    cursorColor: primary,
                                    onChanged: (val) {
                                      setState(() {
                                        _searchQuery = val;
                                      });
                                    },
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8.0,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.clear_circled_solid,
                                        color: textDark.withOpacity(0.4),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: surface.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: textDark,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 18,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: textDark,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Bottom Navigation Bar (Apple-style glassmorphic)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: surface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavBarItem(0, CupertinoIcons.home),
                          _buildNavBarItem(1, CupertinoIcons.plus_app),
                          _buildNavBarItem(2, CupertinoIcons.graph_square),
                          _buildNavBarItem(3, CupertinoIcons.settings),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedTabIndex = index;
        });
        if (index == 1) {
          _openInput();
        } else if (index == 3) {
          _openSettings();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? textDark : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : textDark.withOpacity(0.4),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.square_stack_3d_up,
            color: textDark.withOpacity(0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No notes found',
            style: headingStyle(fontSize: 18, color: textDark.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "+" above to add your first note.',
            style: bodyStyle(color: textMid),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid(List<dynamic> maps, MapProvider provider) {
    return GridView.builder(
      clipBehavior: Clip.none,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 76, bottom: 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemCount: maps.length,
      itemBuilder: (context, index) {
        final map = maps[index];
        final cardColor = _cardColors[index % _cardColors.length];

        return Dismissible(
              key: Key(map.id),
              direction: DismissDirection.endToStart,
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.delete,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),
              onDismissed: (_) async {
                await provider.deleteMap(map.id);
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
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            map.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: headingStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(map.createdAt),
                            style: bodyStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        map.rawText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: bodyStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.6),
                          height: 1.3,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.flowchart,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          Text(
                            '${map.totalNodeCount} nodes',
                            style: bodyStyle(
                              fontSize: 11,
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(delay: (index * 80).ms)
            .scale(begin: const Offset(0.9, 0.9));
      },
    );
  }
}
