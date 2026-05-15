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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
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
            return "Download/$fileName"
        }

        val downloadsDir = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        if (!downloadsDir.exists()) downloadsDir.mkdirs()
        val file = File(downloadsDir, fileName)
        file.writeBytes(bytes)
        return file.absolutePath
    }
}
