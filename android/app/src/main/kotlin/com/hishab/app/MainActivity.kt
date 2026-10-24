package com.hishab.app

import android.content.ContentUris
import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The automatic backup: a file in Downloads/Hishab that stays when the
        // app is removed.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hishab/auto_backup")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                if (name == null || bytes == null) {
                    result.error("failed", "The name and the bytes are needed", null)
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.error("old_android", "Needs Android 10 or newer", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(saveToDownloads(name, bytes))
                } catch (e: Exception) {
                    result.error("failed", e.message, null)
                }
            }
    }

    /// Writes [bytes] to Downloads/Hishab/[name]. A file this app made before
    /// is written over; one left by an earlier install is not ours to change,
    /// so Android gives the new file a number in its name.
    private fun saveToDownloads(name: String, bytes: ByteArray): String {
        val folder = "Download/Hishab/"
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val resolver = contentResolver

        var uri: Uri? = null
        resolver.query(
            collection,
            arrayOf(MediaStore.Downloads._ID),
            "${MediaStore.Downloads.DISPLAY_NAME} = ? AND ${MediaStore.Downloads.RELATIVE_PATH} = ?",
            arrayOf(name, folder),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                uri = ContentUris.withAppendedId(collection, cursor.getLong(0))
            }
        }
        if (uri == null) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, "application/json")
                put(MediaStore.Downloads.RELATIVE_PATH, folder)
            }
            uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("The file could not be created")
        }
        val stream = resolver.openOutputStream(uri!!, "wt")
            ?: throw IllegalStateException("The file could not be opened")
        stream.use { it.write(bytes) }
        return folder + name
    }
}
