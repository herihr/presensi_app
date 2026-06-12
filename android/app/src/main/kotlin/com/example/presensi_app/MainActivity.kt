package com.example.presensi_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val downloadsChannel = "presensi_app/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            downloadsChannel
        ).setMethodCallHandler { call, result ->
            if (call.method == "saveArtifact") {
                val fileName = call.argument<String>("fileName")
                val bytes = call.argument<ByteArray>("bytes")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                val relativeFolder = call.argument<String>("relativeFolder") ?: ""
                if (fileName.isNullOrBlank() || bytes == null) {
                    result.error("INVALID_ARGUMENT", "Nama file atau data artefak tidak valid", null)
                    return@setMethodCallHandler
                }

                try {
                    val savedPath = saveBytesToDownloads(
                        fileName,
                        bytes,
                        mimeType,
                        relativeFolder
                    )
                    result.success(savedPath)
                } catch (error: Exception) {
                    result.error("SAVE_FAILED", error.message, null)
                }
                return@setMethodCallHandler
            }

            if (call.method != "saveExcel" && call.method != "saveReport") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val fileName = call.argument<String>("fileName")
            val content = call.argument<String>("content")
            val mimeType = call.argument<String>("mimeType") ?: "application/vnd.ms-excel"
            if (fileName.isNullOrBlank() || content == null) {
                result.error("INVALID_ARGUMENT", "Nama file atau konten tidak valid", null)
                return@setMethodCallHandler
            }

            try {
                val savedPath = saveTextFileToDownloads(fileName, content, mimeType)
                result.success(savedPath)
            } catch (error: Exception) {
                result.error("SAVE_FAILED", error.message, null)
            }
        }
    }

    private fun saveTextFileToDownloads(
        fileName: String,
        content: String,
        mimeType: String
    ): String {
        val bytes = content.toByteArray(Charsets.UTF_8)
        return saveBytesToDownloads(fileName, bytes, mimeType, "")
    }

    private fun saveBytesToDownloads(
        fileName: String,
        bytes: ByteArray,
        mimeType: String,
        relativeFolder: String
    ): String {
        val safeFolder = relativeFolder
            .replace("\\", "/")
            .split("/")
            .filter { it.isNotBlank() && it != "." && it != ".." }
            .joinToString("/")
        val relativePath = if (safeFolder.isBlank()) {
            Environment.DIRECTORY_DOWNLOADS
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/$safeFolder"
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, relativePath)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Tidak bisa membuat file di folder Download")

            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw IllegalStateException("Tidak bisa menulis file presensi")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "$relativePath/$fileName"
        }

        val downloadsDir = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        if (!downloadsDir.exists()) downloadsDir.mkdirs()
        val targetDir = if (safeFolder.isBlank()) {
            downloadsDir
        } else {
            File(downloadsDir, safeFolder)
        }
        if (!targetDir.exists()) targetDir.mkdirs()
        val file = File(targetDir, fileName)
        file.writeBytes(bytes)
        return file.absolutePath
    }
}
