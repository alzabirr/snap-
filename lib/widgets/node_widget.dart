import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/snap_map_model.dart';
import '../providers/map_provider.dart';
import '../themes/app_theme.dart';
import 'glass_card.dart';

class NodeViewDialog extends StatelessWidget {
  final MindMapNode node;
  final bool isBranch;

  const NodeViewDialog({
    super.key,
    required this.node,
    required this.isBranch,
  });

  @override
  Widget build(BuildContext context) {
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
                      isBranch ? 'Category' : 'Key Point',
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
                
                // Beautifully formatted content display
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: SelectionArea(
                      child: Text(
                        node.title,
                        textAlign: TextAlign.left,
                        style: bodyStyle(
                          fontSize: 16,
                          color: textDark,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Close Button
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: primary,
                  borderRadius: BorderRadius.circular(buttonRadius),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Close',
                    style: headingStyle(fontSize: 16, color: Colors.white),
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
