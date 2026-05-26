import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'snap_map_model.g.dart';

@HiveType(typeId: 0)
class MindMapNode extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  List<MindMapNode> children;
  @HiveField(3)
  int colorValue;        // Color stored as int — Hive cannot store Color directly
  @HiveField(4)
  bool isExpanded;
  @HiveField(5)
  double dx;             // canvas position x
  @HiveField(6)
  double dy;             // canvas position y

  Color get color => Color(colorValue);

  set color(Color newColor) {
    colorValue = newColor.value;
  }

  MindMapNode({
    String? id,
    required this.title,
    List<MindMapNode>? children,
    this.colorValue = 0xFF6366F1,
    this.isExpanded = true,
    this.dx = 0,
    this.dy = 0,
  })  : id = id ?? const Uuid().v4(),
        children = children ?? [];
}

@HiveType(typeId: 1)
class SnapMapData extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  List<MindMapNode> nodes;    // top-level branch nodes
  @HiveField(3)
  DateTime createdAt;
  @HiveField(4)
  String rawText;

  int get totalNodeCount =>
      nodes.fold(0, (sum, n) => sum + 1 + n.children.fold(0, (s, child) => s + 1));

  SnapMapData({
    String? id,
    required this.title,
    required this.nodes,
    required this.rawText,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}
