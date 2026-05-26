import 'package:hive_flutter/hive_flutter.dart';
import '../models/snap_map_model.dart';

class HiveStorage {
  static const String _mapsBox = 'snap_maps';
  static const String _settingsBox = 'snap_settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MindMapNodeAdapter());
    Hive.registerAdapter(SnapMapDataAdapter());
    await Hive.openBox<SnapMapData>(_mapsBox);
    await Hive.openBox(_settingsBox);
  }

  // Save mind map
  Future<void> saveMap(SnapMapData map) async {
    final box = Hive.box<SnapMapData>(_mapsBox);
    await box.put(map.id, map);
  }

  // Load all maps
  Future<List<SnapMapData>> loadAllMaps() async {
    final box = Hive.box<SnapMapData>(_mapsBox);
    final maps = box.values.toList();
    // Sort by createdAt descending
    maps.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return maps;
  }

  // Delete map
  Future<void> deleteMap(String id) async {
    final box = Hive.box<SnapMapData>(_mapsBox);
    await box.delete(id);
  }

  // Check if first launch
  Future<bool> isFirstLaunch() async {
    final box = Hive.box(_settingsBox);
    return box.get('is_first_launch', defaultValue: true) as bool;
  }

  // Set launched (skip onboarding next time)
  Future<void> setLaunched() async {
    final box = Hive.box(_settingsBox);
    await box.put('is_first_launch', false);
  }

  // Helper for generic settings
  Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(_settingsBox);
    await box.put(key, value);
  }

  dynamic getSetting(String key, dynamic defaultValue) {
    final box = Hive.box(_settingsBox);
    return box.get(key, defaultValue: defaultValue);
  }
}
