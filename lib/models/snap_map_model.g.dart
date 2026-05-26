// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'snap_map_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MindMapNodeAdapter extends TypeAdapter<MindMapNode> {
  @override
  final int typeId = 0;

  @override
  MindMapNode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MindMapNode(
      id: fields[0] as String?,
      title: fields[1] as String,
      children: (fields[2] as List?)?.cast<MindMapNode>(),
      colorValue: fields[3] as int,
      isExpanded: fields[4] as bool,
      dx: fields[5] as double,
      dy: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, MindMapNode obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.children)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.isExpanded)
      ..writeByte(5)
      ..write(obj.dx)
      ..writeByte(6)
      ..write(obj.dy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindMapNodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SnapMapDataAdapter extends TypeAdapter<SnapMapData> {
  @override
  final int typeId = 1;

  @override
  SnapMapData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SnapMapData(
      id: fields[0] as String?,
      title: fields[1] as String,
      nodes: (fields[2] as List).cast<MindMapNode>(),
      rawText: fields[4] as String,
      createdAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SnapMapData obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.nodes)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.rawText);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnapMapDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
