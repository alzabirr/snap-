import 'package:flutter/material.dart';
import '../models/snap_map_model.dart';
import '../models/snap_settings.dart';
import '../storage/hive_storage.dart';
import '../themes/app_theme.dart';

class MapProvider with ChangeNotifier {
  final HiveStorage _storage = HiveStorage();

  List<SnapMapData> _maps = [];
  SnapMapData? _selectedMap;
  SnapMapSettings _settings = SnapMapSettings();
  bool _isLoading = false;

  List<SnapMapData> get maps => _maps;
  SnapMapData? get selectedMap => _selectedMap;
  SnapMapSettings get settings => _settings;
  bool get isLoading => _isLoading;

  MapProvider() {
    _loadSettings();
  }

  // Load settings from storage
  void _loadSettings() {
    final theme = _storage.getSetting('themeName', 'Ocean') as String;
    final layout = _storage.getSetting('layout', 'radial') as String;
    final textSize = _storage.getSetting('textSize', 14.0) as double;
    final branchThickness = _storage.getSetting('branchThickness', 2.5) as double;
    final isCompact = _storage.getSetting('isCompact', false) as bool;

    _settings = SnapMapSettings(
      themeName: theme,
      layout: layout,
      textSize: textSize,
      branchThickness: branchThickness,
      isCompact: isCompact,
    );
  }

  // Update specific setting and save to storage
  void updateSetting({
    String? themeName,
    String? layout,
    double? textSize,
    double? branchThickness,
    bool? isCompact,
  }) {
    if (themeName != null) {
      _settings.themeName = themeName;
      _storage.saveSetting('themeName', themeName);
      // When the color theme changes, we update node colors on the selected map
      _applyThemeColorsToSelectedMap();
    }
    if (layout != null) {
      _settings.layout = layout;
      _storage.saveSetting('layout', layout);
    }
    if (textSize != null) {
      _settings.textSize = textSize;
      _storage.saveSetting('textSize', textSize);
    }
    if (branchThickness != null) {
      _settings.branchThickness = branchThickness;
      _storage.saveSetting('branchThickness', branchThickness);
    }
    if (isCompact != null) {
      _settings.isCompact = isCompact;
      _storage.saveSetting('isCompact', isCompact);
    }
    notifyListeners();
  }

  // Load all maps
  Future<void> loadMaps() async {
    _isLoading = true;
    notifyListeners();
    try {
      _maps = await _storage.loadAllMaps();
    } catch (e) {
      debugPrint('Error loading maps: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set active map
  void selectMap(SnapMapData? map) {
    _selectedMap = map;
    if (map != null) {
      _applyThemeColorsToSelectedMap();
    }
    notifyListeners();
  }

  // Save/Create map
  Future<void> saveMap(SnapMapData map) async {
    await _storage.saveMap(map);
    await loadMaps();
    if (_selectedMap?.id == map.id) {
      _selectedMap = map;
    }
    notifyListeners();
  }

  // Delete map
  Future<void> deleteMap(String id) async {
    await _storage.deleteMap(id);
    if (_selectedMap?.id == id) {
      _selectedMap = null;
    }
    await loadMaps();
  }

  // Save active map state
  Future<void> saveActiveMap() async {
    if (_selectedMap != null) {
      await _storage.saveMap(_selectedMap!);
      await loadMaps();
    }
  }

  // Apply colors of selected theme to active map branches
  void _applyThemeColorsToSelectedMap() {
    if (_selectedMap == null) return;
    final palette = themePalettes[_settings.themeName] ?? nodeColors;
    for (int i = 0; i < _selectedMap!.nodes.length; i++) {
      final colorVal = palette[i % palette.length].value;
      _selectedMap!.nodes[i].colorValue = colorVal;
      for (var child in _selectedMap!.nodes[i].children) {
        child.colorValue = colorVal;
      }
    }
  }

  // Node editing actions:
  
  // Toggle expansion state
  void toggleNodeExpansion(MindMapNode node) {
    node.isExpanded = !node.isExpanded;
    saveActiveMap();
    notifyListeners();
  }

  // Update node position from drag
  void updateNodePosition(MindMapNode node, double dx, double dy) {
    node.dx = dx;
    node.dy = dy;
    saveActiveMap();
    notifyListeners();
  }

  // Edit node title
  void editNodeTitle(MindMapNode node, String newTitle) {
    node.title = newTitle;
    saveActiveMap();
    notifyListeners();
  }

  // Add child node
  void addChildNode(MindMapNode parent, String title) {
    if (_selectedMap == null) return;
    parent.children.add(MindMapNode(
      title: title,
      colorValue: parent.colorValue,
    ));
    saveActiveMap();
    notifyListeners();
  }

  // Add branch node
  void addBranchNode(String title) {
    if (_selectedMap == null) return;
    final palette = themePalettes[_settings.themeName] ?? nodeColors;
    final colorVal = palette[_selectedMap!.nodes.length % palette.length].value;
    _selectedMap!.nodes.add(MindMapNode(
      title: title,
      colorValue: colorVal,
    ));
    saveActiveMap();
    notifyListeners();
  }

  // Delete node (could be a branch or a child)
  void deleteNodeFromActiveMap(String nodeId) {
    if (_selectedMap == null) return;
    
    // Check if it's a top-level branch
    int index = _selectedMap!.nodes.indexWhere((n) => n.id == nodeId);
    if (index != -1) {
      _selectedMap!.nodes.removeAt(index);
    } else {
      // Check if it's a child node under a branch
      for (var branch in _selectedMap!.nodes) {
        int childIndex = branch.children.indexWhere((c) => c.id == nodeId);
        if (childIndex != -1) {
          branch.children.removeAt(childIndex);
          break;
        }
      }
    }
    saveActiveMap();
    notifyListeners();
  }

  // Reset node positions (recalculate layout automatically)
  void resetNodePositions() {
    if (_selectedMap == null) return;
    for (var node in _selectedMap!.nodes) {
      node.dx = 0;
      node.dy = 0;
      for (var child in node.children) {
        child.dx = 0;
        child.dy = 0;
      }
    }
    saveActiveMap();
    notifyListeners();
  }
}
