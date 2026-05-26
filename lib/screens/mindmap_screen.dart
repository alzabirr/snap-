import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import '../models/snap_map_model.dart';
import '../providers/map_provider.dart';
import '../themes/app_theme.dart';
import '../utils/export_helper.dart';
import '../widgets/customization_panel.dart';
import '../widgets/glass_card.dart';
import '../widgets/ambient_background.dart';
import '../widgets/mind_map_painter.dart';
import '../widgets/node_widget.dart';

class MindmapScreen extends StatefulWidget {
  const MindmapScreen({super.key});

  @override
  State<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends State<MindmapScreen> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  
  Offset _lastTapDownPosition = Offset.zero;
  bool _isDragging = false;
  MindMapNode? _draggingNode;

  @override
  void initState() {
    super.initState();
    // Animation for idle float
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Center the viewport initially on the 3000x3000px canvas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerViewport();
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _centerViewport() {
    // Center of 3000x3000px canvas is (1500, 1500)
    // Screen size is usually around (400, 800)
    // We want the center of the screen to align with the center of the canvas.
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    final double xOffset = -(1500 - screenWidth / 2);
    final double yOffset = -(1500 - screenHeight / 2);
    
    // Set scale to 1.0 or slightly zoomed out
    _transformationController.value = Matrix4.identity()
      ..translate(xOffset, yOffset);
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

  void _showCustomizationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (context) => const CustomizationPanel(),
    );
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  Text('Export Canvas', style: headingStyle(fontSize: 18, color: textDark), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  
                  // Save PNG
                  CupertinoButton(
                    color: primary,
                    borderRadius: BorderRadius.circular(buttonRadius),
                    onPressed: () async {
                      Navigator.pop(context);
                      _triggerCapture(action: 'save');
                    },
                    child: Text('Save PNG to Documents', style: headingStyle(fontSize: 14, color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  
                  // Share
                  CupertinoButton(
                    color: accent,
                    borderRadius: BorderRadius.circular(buttonRadius),
                    onPressed: () async {
                      Navigator.pop(context);
                      _triggerCapture(action: 'share');
                    },
                    child: Text('Share mind map', style: headingStyle(fontSize: 14, color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  
                  // Save to Gallery
                  CupertinoButton(
                    color: textDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(buttonRadius),
                    onPressed: () async {
                      Navigator.pop(context);
                      _triggerCapture(action: 'gallery');
                    },
                    child: Text('Save to Gallery', style: headingStyle(fontSize: 14, color: textDark)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _triggerCapture({required String action}) async {
    // Show hud
    showCupertinoDialog(
      context: context,
      builder: (context) => const Center(child: CupertinoActivityIndicator(radius: 16)),
    );

    try {
      final RenderRepaintBoundary? boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('RepaintBoundary render object not found');
      }
      final imagePath = await ExportHelper.capturePng(boundary);
      
      // pop hud
      if (mounted) Navigator.pop(context);

      if (action == 'share') {
        await ExportHelper.shareImage(imagePath);
      } else if (action == 'save') {
        final path = await ExportHelper.saveToGallery(imagePath);
        if (mounted) {
          _showToast('Map saved to Documents:\n$path');
        }
      } else if (action == 'gallery') {
        await ExportHelper.saveToGallery(imagePath);
        if (mounted) {
          _showToast('Saved to device gallery successfully!');
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showToast('Export failed — try again');
    }
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MapProvider>(context);
    final data = provider.selectedMap;
    if (data == null) {
      return const Scaffold(body: Center(child: Text('No active map')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: textDark, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          data.title,
          style: headingStyle(fontSize: 20, color: textDark),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(CupertinoIcons.share, color: textDark, size: 22),
            onPressed: _showExportSheet,
          ),
        ],
      ),
      body: AmbientBackground(
        child: Stack(
          children: [
            // Mind Map Zoomable Canvas
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.3,
              maxScale: 4.0,
              constrained: false,
              panEnabled: !_isDragging,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: GestureDetector(
                onTapDown: _handleTapDown,
                onTap: _handleTap,
                onDoubleTap: _handleDoubleTap,
                onLongPressStart: _handleLongPressStart,
                onLongPressMoveUpdate: _handleLongPressMoveUpdate,
                onLongPressEnd: _handleLongPressEnd,
                child: AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) {
                    return RepaintBoundary(
                      key: _boundaryKey,
                      child: Container(
                        width: 3000,
                        height: 3000,
                        color: Colors.transparent,
                        child: CustomPaint(
                        painter: MindMapPainter(
                          data: data,
                          settings: provider.settings,
                          floatOffset: _floatController.value * 2 * pi,
                        ),
                      ),
                    ),
                  );
                },
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
                      // Themes
                      _buildDockButton(
                        icon: CupertinoIcons.color_filter,
                        label: 'Themes',
                        onTap: _showCustomizationSheet,
                      ),
                      _buildDivider(),
                      // Layout
                      _buildDockButton(
                        icon: CupertinoIcons.square_grid_2x2,
                        label: 'Layout',
                        onTap: _showCustomizationSheet,
                      ),
                      _buildDivider(),
                      // Options
                      _buildDockButton(
                        icon: CupertinoIcons.settings,
                        label: 'Options',
                        onTap: _showCustomizationSheet,
                      ),
                      _buildDivider(),
                      // Export
                      _buildDockButton(
                        icon: CupertinoIcons.square_arrow_up,
                        label: 'Export',
                        onTap: _showExportSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().slideY(begin: 0.8, end: 0, curve: Curves.easeOutBack, duration: 500.ms),
        ],
      )),
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
