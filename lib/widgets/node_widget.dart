import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/snap_map_model.dart';
import '../providers/map_provider.dart';
import '../themes/app_theme.dart';
import 'glass_card.dart';

class NodeEditDialog extends StatefulWidget {
  final MindMapNode node;
  final bool isBranch;

  const NodeEditDialog({
    super.key,
    required this.node,
    required this.isBranch,
  });

  @override
  State<NodeEditDialog> createState() => _NodeEditDialogState();
}

class _NodeEditDialogState extends State<NodeEditDialog> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.node.title);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MapProvider>(context, listen: false);

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isBranch ? 'Edit Category' : 'Edit Key Point',
                      style: headingStyle(fontSize: 18, color: textDark),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(CupertinoIcons.clear_thick, color: textMid, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Text input
                CupertinoTextField(
                  controller: _textController,
                  autofocus: true,
                  placeholder: 'Enter title...',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  style: bodyStyle(fontSize: 14, color: textDark),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    // Delete Button
                    Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: CupertinoColors.systemRed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(buttonRadius),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          provider.deleteNodeFromActiveMap(widget.node.id);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Delete',
                          style: headingStyle(fontSize: 14, color: CupertinoColors.systemRed),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Save Button
                    Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: primary,
                        borderRadius: BorderRadius.circular(buttonRadius),
                        onPressed: () {
                          final newTitle = _textController.text.trim();
                          if (newTitle.isNotEmpty) {
                            HapticFeedback.lightImpact();
                            provider.editNodeTitle(widget.node, newTitle);
                          }
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Save',
                          style: headingStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Add child option (if it is a branch node)
                if (widget.isBranch) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(color: Colors.white24, height: 1),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(buttonRadius),
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddChildDialog(context, provider, widget.node);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.add, color: accent, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Add Key Point child',
                          style: headingStyle(fontSize: 13, color: accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, MapProvider provider, MindMapNode parentNode) {
    final childTextController = TextEditingController();
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
                      'Add Key Point under "${parentNode.title}"',
                      style: headingStyle(fontSize: 16, color: textDark),
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: childTextController,
                      autofocus: true,
                      placeholder: 'Key point description...',
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
                            child: Text(
                              'Cancel',
                              style: headingStyle(fontSize: 13, color: textDark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: primary,
                            borderRadius: BorderRadius.circular(buttonRadius),
                            onPressed: () {
                              final text = childTextController.text.trim();
                              if (text.isNotEmpty) {
                                HapticFeedback.lightImpact();
                                provider.addChildNode(parentNode, text);
                              }
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Add',
                              style: headingStyle(fontSize: 13, color: Colors.white),
                            ),
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
}
