import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../storage/hive_storage.dart';

class LocalModelInfo {
  final String name;
  final String fileName;
  final String url;
  final String approximateSize;

  const LocalModelInfo({
    required this.name,
    required this.fileName,
    required this.url,
    required this.approximateSize,
  });
}

class LocalModelService {
  static final ValueNotifier<double> downloadProgress = ValueNotifier(0);
  static final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  static Future<String>? _activeDownload;

  static const LocalModelInfo defaultModel = LocalModelInfo(
    name: 'Gemma 3 1B IT Q4',
    fileName: 'gemma-3-1b-it-q4_k_m.gguf',
    url:
        'https://huggingface.co/itlwas/gemma-3-1b-it-Q4_K_M-GGUF/resolve/main/gemma-3-1b-it-q4_k_m.gguf',
    approximateSize: 'about 800 MB',
  );

  static const String _modelPathKey = 'local_model_path';
  static const String _modelNameKey = 'local_model_name';

  static Future<String> _modelsDirectoryPath() async {
    final dir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${dir.path}${Platform.pathSeparator}models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  static Future<String?> savedModelPath() async {
    final path = HiveStorage().getSetting(_modelPathKey, null) as String?;
    if (path == null) return null;
    return await File(path).exists() ? path : null;
  }

  static Future<bool> hasDownloadedModel() async {
    return await savedModelPath() != null;
  }

  static Future<void> deleteDownloadedModel() async {
    final path = await savedModelPath();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final storage = HiveStorage();
    await storage.saveSetting(_modelPathKey, null);
    await storage.saveSetting(_modelNameKey, null);
  }

  static Future<String> downloadDefaultModel({
    required void Function(double progress) onProgress,
  }) async {
    if (_activeDownload != null) return _activeDownload!;
    _activeDownload = _downloadDefaultModel(onProgress: onProgress);
    try {
      return await _activeDownload!;
    } finally {
      _activeDownload = null;
      isDownloading.value = false;
    }
  }

  static Future<String> ensureDefaultModelDownloaded() async {
    final saved = await savedModelPath();
    if (saved != null) {
      downloadProgress.value = 1;
      return saved;
    }
    return downloadDefaultModel(
      onProgress: (progress) => downloadProgress.value = progress,
    );
  }

  static Future<String> _downloadDefaultModel({
    required void Function(double progress) onProgress,
  }) async {
    isDownloading.value = true;
    downloadProgress.value = 0;
    final modelsPath = await _modelsDirectoryPath();
    final destinationPath =
        '$modelsPath${Platform.pathSeparator}${defaultModel.fileName}';
    final destination = File(destinationPath);
    final partial = File('$destinationPath.part');

    final request = await HttpClient().getUrl(Uri.parse(defaultModel.url));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Model download failed: HTTP ${response.statusCode}');
    }

    final sink = partial.openWrite();
    final total = response.contentLength;
    var received = 0;

    await for (final chunk in response) {
      received += chunk.length;
      sink.add(chunk);
      if (total > 0) {
        onProgress(received / total);
        downloadProgress.value = received / total;
      }
    }

    await sink.flush();
    await sink.close();

    if (await destination.exists()) {
      await destination.delete();
    }
    await partial.rename(destinationPath);

    final storage = HiveStorage();
    await storage.saveSetting(_modelPathKey, destinationPath);
    await storage.saveSetting(_modelNameKey, defaultModel.name);
    onProgress(1);
    downloadProgress.value = 1;
    isDownloading.value = false;

    return destinationPath;
  }
}
