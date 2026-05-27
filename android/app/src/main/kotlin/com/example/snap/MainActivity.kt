package com.example.snap

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val modelPrefs by lazy {
        applicationContext.getSharedPreferences("snap_model_download", Context.MODE_PRIVATE)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Natively set status bar and system navigation bar transparent and edge-to-edge
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "snap/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("missing_path", "Image path is required.", null)
                    return@setMethodCallHandler
                }

                val imageFile = File(path)
                if (!imageFile.exists()) {
                    result.error("missing_file", "Image file does not exist.", null)
                    return@setMethodCallHandler
                }

                val imageUri = FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    imageFile,
                )

                val text = call.argument<String>("text") ?: ""
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "image/png"
                    putExtra(Intent.EXTRA_STREAM, imageUri)
                    putExtra(Intent.EXTRA_TEXT, text)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }

                startActivity(Intent.createChooser(shareIntent, "Share mind map"))
                result.success(null)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "snap/model_download")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startDefaultModelDownload" -> {
                        val url = call.argument<String>("url")
                        val fileName = call.argument<String>("fileName")
                        val title = call.argument<String>("title") ?: "Snap local AI model"

                        if (url.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error("missing_args", "Model url and fileName are required.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val modelFile = File(getExternalFilesDir(null), "models/$fileName")
                            if (modelFile.exists() && modelFile.length() > 0L) {
                                modelPrefs.edit()
                                    .putString("path", modelFile.absolutePath)
                                    .remove("download_id")
                                    .apply()
                                result.success(mapOf("status" to "complete", "path" to modelFile.absolutePath))
                                return@setMethodCallHandler
                            }

                            val activeId = modelPrefs.getLong("download_id", -1L)
                            val activeStatus = queryDownload(activeId)
                            if (activeStatus["status"] == "running" || activeStatus["status"] == "pending") {
                                result.success(activeStatus)
                                return@setMethodCallHandler
                            }

                            val modelsDir = File(getExternalFilesDir(null), "models")
                            if (!modelsDir.exists()) modelsDir.mkdirs()
                            val partialFileName = "$fileName.part"
                            File(modelsDir, partialFileName).delete()

                            val request = DownloadManager.Request(Uri.parse(url))
                                .setTitle(title)
                                .setDescription("Downloading local AI model")
                                .setNotificationVisibility(
                                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
                                )
                                .setAllowedOverMetered(true)
                                .setAllowedOverRoaming(true)
                                .setDestinationInExternalFilesDir(
                                    this,
                                    Environment.DIRECTORY_DOWNLOADS,
                                    "models/$partialFileName",
                                )

                            val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                            val downloadId = manager.enqueue(request)
                            val partialPath = File(
                                getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
                                "models/$partialFileName",
                            ).absolutePath
                            modelPrefs.edit()
                                .putLong("download_id", downloadId)
                                .putString("path", modelFile.absolutePath)
                                .putString("partial_path", partialPath)
                                .putString("file_name", fileName)
                                .apply()

                            result.success(queryDownload(downloadId))
                        } catch (e: Exception) {
                            result.error("download_start_failed", e.message, null)
                        }
                    }

                    "getDefaultModelDownloadStatus" -> {
                        val downloadId = modelPrefs.getLong("download_id", -1L)
                        result.success(queryDownload(downloadId))
                    }

                    "clearDefaultModelDownload" -> {
                        val downloadId = modelPrefs.getLong("download_id", -1L)
                        if (downloadId > 0L) {
                            val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                            manager.remove(downloadId)
                        }
                        modelPrefs.edit().clear().apply()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun queryDownload(downloadId: Long): Map<String, Any?> {
        val savedPath = modelPrefs.getString("path", null)
        if (!savedPath.isNullOrBlank()) {
            val savedFile = File(savedPath)
            if (savedFile.exists() && savedFile.length() > 0L) {
                return mapOf("status" to "complete", "path" to savedFile.absolutePath, "progress" to 1.0)
            }
        }

        if (downloadId <= 0L) {
            return mapOf("status" to "idle", "progress" to 0.0)
        }

        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val cursor = manager.query(DownloadManager.Query().setFilterById(downloadId))
            ?: return mapOf("status" to "idle", "progress" to 0.0)

        cursor.use {
            if (!it.moveToFirst()) return mapOf("status" to "idle", "progress" to 0.0)

            val status = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val downloaded = it.getLong(
                it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
            )
            val total = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            val progress = if (total > 0L) downloaded.toDouble() / total.toDouble() else 0.0

            return when (status) {
                DownloadManager.STATUS_SUCCESSFUL -> finishDownload()
                DownloadManager.STATUS_FAILED -> {
                    val reason = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
                    mapOf("status" to "failed", "progress" to progress, "reason" to reason)
                }
                DownloadManager.STATUS_PAUSED -> mapOf("status" to "paused", "progress" to progress)
                DownloadManager.STATUS_PENDING -> mapOf("status" to "pending", "progress" to progress)
                DownloadManager.STATUS_RUNNING -> mapOf("status" to "running", "progress" to progress)
                else -> mapOf("status" to "idle", "progress" to progress)
            }
        }
    }

    private fun finishDownload(): Map<String, Any?> {
        val partialPath = modelPrefs.getString("partial_path", null)
        val finalPath = modelPrefs.getString("path", null)

        if (!partialPath.isNullOrBlank() && !finalPath.isNullOrBlank()) {
            val partial = File(partialPath)
            val finalFile = File(finalPath)
            if (partial.exists()) {
                finalFile.parentFile?.mkdirs()
                if (finalFile.exists()) finalFile.delete()
                partial.renameTo(finalFile)
            }
            if (finalFile.exists() && finalFile.length() > 0L) {
                modelPrefs.edit().remove("download_id").apply()
                return mapOf("status" to "complete", "path" to finalFile.absolutePath, "progress" to 1.0)
            }
        }

        return mapOf("status" to "failed", "progress" to 1.0)
    }
}
