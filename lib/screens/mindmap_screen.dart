import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/snap_map_model.dart';
import '../providers/map_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/mind_map_painter.dart';
import '../widgets/node_widget.dart';
import 'flashcards_screen.dart';

class MindmapScreen extends StatefulWidget {
  const MindmapScreen({super.key});

  @override
  State<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends State<MindmapScreen> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _revealController;
  final TransformationController _transformationController = TransformationController();
  
  Offset _lastTapDownPosition = Offset.zero;
  bool _isDragging = false;
  MindMapNode? _draggingNode;
  String? _revealingBranchId;

  @override
  void initState() {
    super.initState();
    // Animation for idle float
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _revealController = AnimationController(
      duration: const Duration(milliseconds: 360),
      vsync: this,
    );

    // Center the viewport initially on the 3000x3000px canvas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _collapseBranchesForFocusedView();
      _centerViewport();
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _revealController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _collapseBranchesForFocusedView() {
    final provider = Provider.of<MapProvider>(context, listen: false);
    final data = provider.selectedMap;
    if (data == null) return;
    setState(() {
      for (final branch in data.nodes) {
        branch.isExpanded = false;
      }
    });
  }

  void _centerViewport() {
    final provider = Provider.of<MapProvider>(context, listen: false);
    final data = provider.selectedMap;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    var contentCenter = const Offset(1500, 1500);
    var scale = 0.78;

    if (data != null) {
      final positions = MindMapLayoutHelper.getPositions(
        data,
        provider.settings,
        floatOffset: 0,
      );
      if (positions.isNotEmpty) {
        var left = double.infinity;
        var top = double.infinity;
        var right = -double.infinity;
        var bottom = -double.infinity;

        for (final point in positions.values) {
          left = min(left, point.dx);
          top = min(top, point.dy);
          right = max(right, point.dx);
          bottom = max(bottom, point.dy);
        }

        final width = (right - left).clamp(1, double.infinity).toDouble();
        final height = (bottom - top).clamp(1, double.infinity).toDouble();
        contentCenter = Offset((left + right) / 2, (top + bottom) / 2);
        scale = min(
          screenWidth / (width + 260),
          screenHeight / (height + 280),
        ).clamp(0.32, 0.9).toDouble();
      }
    }

    final double xOffset = screenWidth / 2 - contentCenter.dx * scale;
    final double yOffset = screenHeight / 2 - contentCenter.dy * scale;

    _transformationController.value = Matrix4.identity()
      ..translate(xOffset, yOffset)
      ..scale(scale);
  }

  void _handleTapDown(TapDownDetails details) {
    _lastTapDownPosition = details.localPosition;
  }

  void _handleTap() {
    final provider = Provider.of<MapProvider>(context, listen: false);
    final data = provider.selectedMap;
    if (data == null) return;

    final hitResult = _hitTest(data, provider.settings, _lastTapDownPosition);
    if (hitResult != null) {
      if (hitResult.isRoot) {
        // Double check/edit root title if clicked?
        _showEditRootTitleDialog(context, provider, data);
      } else if (hitResult.node != null && hitResult.isBranch) {
        HapticFeedback.lightImpact();
        setState(() {
          _revealingBranchId = hitResult.node!.id;
        });
        provider.toggleNodeExpansion(hitResult.node!);
        if (hitResult.node!.isExpanded) {
          _revealController.forward(from: 0);
        }
      } else if (hitResult.node != null) {
        // Show edit/delete dialog
        showCupertinoDialog(
          context: context,
          builder: (context) => NodeEditDialog(
            node: hitResult.node!,
            isBranch: hitResult.isBranch,
          ),
        );
      }
    }
  }

  void _handleDoubleTap() {
    final provider = Provider.of<MapProvider>(context, listen: false);
    final data = provider.selectedMap;
    if (data == null) return;

    final hitResult = _hitTest(data, provider.settings, _lastTapDownPosition);
    if (hitResult != null && hitResult.node != null && hitResult.isBranch) {
      // Toggle expanded state
      HapticFeedback.lightImpact();
      provider.toggleNodeExpansion(hitResult.node!);
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final provider = Provider.of<MapProvider>(context, listen: false);
    final data = provider.selectedMap;
    if (data == null) return;

    final hitResult = _hitTest(data, provider.settings, details.localPosition);
    if (hitResult != null && hitResult.node != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _draggingNode = hitResult.node;
        _isDragging = true;
      });
    }
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_draggingNode != null) {
      final provider = Provider.of<MapProvider>(context, listen: false);
      provider.updateNodePosition(_draggingNode!, details.localPosition.dx, details.localPosition.dy);
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _draggingNode = null;
      _isDragging = false;
    });
  }

  _HitTestResult? _hitTest(SnapMapData data, settings, Offset localPos) {
    final positions = MindMapLayoutHelper.getPositions(data, settings, floatOffset: 0.0);

    // Check root node
    final rootPos = positions['root'];
    if (rootPos != null && (localPos - rootPos).distance <= 55) {
      return _HitTestResult(isRoot: true);
    }

    // Check branches
    for (var branch in data.nodes) {
      final pos = positions[branch.id];
      if (pos != null) {
        final rect = Rect.fromCenter(center: pos, width: 130, height: 46);
        if (rect.contains(localPos)) {
          return _HitTestResult(node: branch, isBranch: true);
        }
      }

      // Check children
      if (branch.isExpanded) {
        for (var child in branch.children) {
          final pos = positions[child.id];
          if (pos != null) {
            final rect = Rect.fromCenter(center: pos, width: 110, height: 36);
            if (rect.contains(localPos)) {
              return _HitTestResult(node: child, isBranch: false);
            }
          }
        }
      }
    }
    return null;
  }

  void _showEditRootTitleDialog(BuildContext context, MapProvider provider, SnapMapData data) {
    final textController = TextEditingController(text: data.title);
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: glassCard(
                opacity: 0.25,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Rename Root Topic',
                      style: headingStyle(fontSize: 18, color: textDark),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: textController,
                      autofocus: true,
                      placeholder: 'Topic name...',
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      style: bodyStyle(fontSize: 14, color: textDark),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(buttonRadius),
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel', style: headingStyle(fontSize: 13, color: textDark)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: primary,
                            borderRadius: BorderRadius.circular(buttonRadius),
                            onPressed: () {
                              final text = textController.text.trim();
                              if (text.isNotEmpty) {
                                HapticFeedback.lightImpact();
                                data.title = text;
                                provider.saveActiveMap();
                              }
                              Navigator.pop(context);
                            },
                            child: Text('Save', style: headingStyle(fontSize: 13, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLayoutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (context) {
        final provider = Provider.of<MapProvider>(context, listen: false);
        final settings = provider.settings;
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surface.withOpacity(0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border.all(color: textDark.withOpacity(0.08), width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Layout', style: headingStyle(fontSize: 18, color: textDark), textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: settings.layout,
                    children: {
                      'radial': Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Radial', style: bodyStyle(fontSize: 13, color: textDark)),
                      ),
                      'tree': Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Tree', style: bodyStyle(fontSize: 13, color: textDark)),
                      ),
                      'horizontal': Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Horiz', style: bodyStyle(fontSize: 13, color: textDark)),
                      ),
                      'vertical': Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Vert', style: bodyStyle(fontSize: 13, color: textDark)),
                      ),
                    },
                    onValueChanged: (val) {
                      if (val != null) {
                        provider.updateSetting(layout: val);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _centerViewport();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  CupertinoButton(
                    color: primary,
                    borderRadius: BorderRadius.circular(buttonRadius),
                    onPressed: () {
                      provider.resetNodePositions();
                      _centerViewport();
                      Navigator.pop(context);
                    },
                    child: Text('Apply Layout', style: headingStyle(fontSize: 14, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showToast(String message) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(message, style: bodyStyle(color: textDark)),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showSummary(SnapMapData data) {
    final summaryNode = data.nodes.where((node) => node.title.toLowerCase().contains('summary')).toList();
    final points = summaryNode.isNotEmpty
        ? summaryNode.first.children.map((child) => child.title).toList()
        : data.nodes.expand((node) => node.children).take(5).map((child) => child.title).toList();
    _showInfoSheet('Summary', points.isEmpty ? ['No summary available.'] : points);
  }

  void _showQuestions(SnapMapData data) {
    final questionNode = data.nodes.where((node) => node.title.toLowerCase().contains('question')).toList();
    final points = questionNode.isNotEmpty
        ? questionNode.first.children.map((child) => child.title).toList()
        : data.nodes.expand((node) => node.children).take(5).map((child) => 'What should you remember about ${child.title}?').toList();
    _showInfoSheet('Questions', points.isEmpty ? ['No questions available.'] : points);
  }

  void _openFlashcards(SnapMapData data) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => FlashcardsScreen(initialMapId: data.id),
      ),
    );
  }

  void _showInfoSheet(String title, List<String> points) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
            decoration: BoxDecoration(
              color: surface.withOpacity(0.88),
              border: Border.all(color: textDark.withOpacity(0.08), width: 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: headingStyle(fontSize: 18, color: textDark), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ...points.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 8, right: 10),
                          decoration: const BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: bodyStyle(fontSize: 14, color: textDark, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MapProvider>(context);
    final data = provider.selectedMap;
    if (data == null) {
      return const Scaffold(body: Center(child: Text('No active map')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Mind Map Zoomable Canvas
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.05,
              maxScale: 80.0,
              scaleEnabled: true,
              constrained: false,
              panEnabled: !_isDragging,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: GestureDetector(
                onTapDown: _handleTapDown,
                onTap: _handleTap,
                onLongPressStart: _handleLongPressStart,
                onLongPressMoveUpdate: _handleLongPressMoveUpdate,
                onLongPressEnd: _handleLongPressEnd,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_floatController, _revealController]),
                  builder: (context, child) {
                    return Container(
                        width: 3000,
                        height: 3000,
                        color: Colors.transparent,
                        child: CustomPaint(
                        painter: MindMapPainter(
                          data: data,
                          settings: provider.settings,
                          floatOffset: _floatController.value * 2 * pi,
                          revealBranchId: _revealingBranchId,
                          revealProgress: Curves.easeOutCubic.transform(_revealController.value),
                        ),
                      ),
                    );
                },
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 12,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: textDark.withValues(alpha: 0.08)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.chevron_left,
                  color: textDark,
                  size: 22,
                ),
              ),
            ),
          ),

          // Bottom Floating Dock Toolbar (glass, centered, pill-shaped)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: SafeArea(
              child: Center(
                child: glassCard(
                  opacity: 0.22,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  borderRadius: BorderRadius.circular(30),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDockButton(
                        icon: CupertinoIcons.square_grid_2x2,
                        label: 'Layout',
                        onTap: _showLayoutSheet,
                      ),
                      _buildDivider(),
                      _buildDockButton(
                        icon: CupertinoIcons.doc_text,
                        label: 'Summary',
                        onTap: () => _showSummary(data),
                      ),
                      _buildDivider(),
                      _buildDockButton(
                        icon: CupertinoIcons.question_circle,
                        label: 'Questions',
                        onTap: () => _showQuestions(data),
                      ),
                      _buildDivider(),
                      _buildDockButton(
                        icon: CupertinoIcons.rectangle_stack,
                        label: 'Flashcards',
                        onTap: () => _openFlashcards(data),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: 0.8, end: 0, curve: Curves.easeOutBack, duration: 500.ms),
        ],
      ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1.2,
      height: 24,
      color: textDark.withOpacity(0.15),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildDockButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textDark, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: headingStyle(fontSize: 10, color: textDark, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _HitTestResult {
  final MindMapNode? node;
  final bool isBranch;
  final bool isRoot;

  _HitTestResult({
    this.node,
    this.isBranch = false,
    this.isRoot = false,
  });
}
