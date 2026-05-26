import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ExportHelper {
  static const MethodChannel _shareChannel = MethodChannel('snap/share');

  // 1. Capture mind map as PNG using RenderRepaintBoundary
  static Future<String> capturePng(RenderRepaintBoundary boundary) async {
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to capture canvas screenshot');
    }
    final pngBytes = byteData.buffer.asUint8List();

    final directory = await getTemporaryDirectory();
    final fileName = 'snap_map_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pngBytes);
    return file.path;
  }

  // 2. Share PNG via system share sheet
  static Future<void> shareImage(String filePath) async {
    await _shareChannel.invokeMethod<void>('shareImage', {
      'path': filePath,
      'text': 'Check out my Snap Mind Map!',
    });
  }

  // 3. Save to device gallery / documents folder
  static Future<String> saveToGallery(String filePath) async {
    final file = File(filePath);
    final directory = await getApplicationDocumentsDirectory();
    final destinationPath =
        '${directory.path}/snap_saved_${DateTime.now().millisecondsSinceEpoch}.png';
    await file.copy(destinationPath);
    return destinationPath;
  }
}
