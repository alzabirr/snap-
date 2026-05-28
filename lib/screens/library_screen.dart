import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, DismissDirection, Dismissible;
import 'package:provider/provider.dart';

import '../providers/map_provider.dart';
import '../themes/app_theme.dart';
import 'mindmap_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

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
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MapProvider>(context);
    final maps = provider.maps.where((map) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return map.title.toLowerCase().contains(q) ||
          map.rawText.toLowerCase().contains(q);
    }).toList();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 18, 10),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        color: textDark,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Library',
                    style: headingStyle(
                      fontSize: 26,
                      color: textDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search saved maps',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: maps.isEmpty
                  ? Center(
                      child: Text(
                        'No saved maps',
                        style: bodyStyle(color: textMid, fontWeight: FontWeight.w700),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      itemCount: maps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final map = maps[index];
                        return Dismissible(
                          key: Key(map.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => provider.deleteMap(map.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              CupertinoIcons.delete,
                              color: Color(0xFFFF3B30),
                            ),
                          ),
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              provider.selectMap(map);
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) => const MindmapScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: textDark.withValues(alpha: 0.07),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.flowchart,
                                      color: primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          map.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: bodyStyle(
                                            fontSize: 16,
                                            color: textDark,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_formatDate(map.createdAt)} • ${map.totalNodeCount} nodes',
                                          style: bodyStyle(
                                            fontSize: 12,
                                            color: textMid,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_forward,
                                    color: textMid,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
