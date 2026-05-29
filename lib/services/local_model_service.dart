import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _androidDownloadChannel = MethodChannel(
    'snap/model_download',
  );
  static Future<String>? _activeDownload;

  static const LocalModelInfo defaultModel = LocalModelInfo(
    name: 'TinyLlama 1.1B Chat Q4',
    fileName: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    url:
        'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    approximateSize: 'about 669 MB',
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
    if (!kIsWeb && Platform.isAndroid) {
      await _androidDownloadChannel.invokeMethod<void>(
        'clearDefaultModelDownload',
      );
    }
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
    await syncBackgroundDownloadStatus();
    final synced = await savedModelPath();
    if (synced != null) {
      downloadProgress.value = 1;
      return synced;
    }
    return downloadDefaultModel(
      onProgress: (progress) => downloadProgress.value = progress,
    );
  }

  static Future<void> syncBackgroundDownloadStatus() async {
    if (kIsWeb || !Platform.isAndroid) return;

    final status = await _getAndroidDownloadStatus();
    await _applyAndroidDownloadStatus(status);
  }

  static Future<String> _downloadDefaultModel({
    required void Function(double progress) onProgress,
  }) async {
    if (!kIsWeb && Platform.isAndroid) {
      return _downloadDefaultModelWithAndroidManager(onProgress: onProgress);
    }

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

  static Future<String> _downloadDefaultModelWithAndroidManager({
    required void Function(double progress) onProgress,
  }) async {
    isDownloading.value = true;

    var status = await _startAndroidDownload();
    while (true) {
      final path = await _applyAndroidDownloadStatus(status);
      final progress = _progressFromStatus(status);
      onProgress(progress);
      downloadProgress.value = progress;

      if (path != null) {
        isDownloading.value = false;
        return path;
      }

      final state = status['status'] as String? ?? 'idle';
      if (state == 'failed') {
        isDownloading.value = false;
        throw Exception('Model download failed');
      }

      await Future<void>.delayed(const Duration(seconds: 1));
      status = await _getAndroidDownloadStatus();
    }
  }

  static Future<Map<String, dynamic>> _startAndroidDownload() async {
    final result = await _androidDownloadChannel
        .invokeMapMethod<String, dynamic>('startDefaultModelDownload', {
          'url': defaultModel.url,
          'fileName': defaultModel.fileName,
          'title': defaultModel.name,
        });
    return result ?? const <String, dynamic>{'status': 'idle'};
  }

  static Future<Map<String, dynamic>> _getAndroidDownloadStatus() async {
    final result = await _androidDownloadChannel
        .invokeMapMethod<String, dynamic>('getDefaultModelDownloadStatus');
    return result ?? const <String, dynamic>{'status': 'idle'};
  }

  static Future<String?> _applyAndroidDownloadStatus(
    Map<String, dynamic> status,
  ) async {
    final state = status['status'] as String? ?? 'idle';
    final progress = _progressFromStatus(status);
    downloadProgress.value = progress;
    isDownloading.value =
        state == 'running' || state == 'pending' || state == 'paused';

    if (state != 'complete') return null;

    final path = status['path'] as String?;
    if (path == null || !await File(path).exists()) return null;

    final storage = HiveStorage();
    await storage.saveSetting(_modelPathKey, path);
    await storage.saveSetting(_modelNameKey, defaultModel.name);
    downloadProgress.value = 1;
    isDownloading.value = false;
    return path;
  }

  static double _progressFromStatus(Map<String, dynamic> status) {
    final progress = status['progress'];
    if (progress is num) return progress.toDouble().clamp(0, 1);
    return 0;
  }
}
