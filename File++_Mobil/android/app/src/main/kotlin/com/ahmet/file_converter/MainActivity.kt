package com.ahmet.file_converter

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ahmet.file_converter/incoming_files"
    private var pendingFiles: ArrayList<String> = ArrayList()
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFiles" -> {
                    val files = ArrayList(pendingFiles)
                    pendingFiles.clear()
                    result.success(files)
                }
                "reset" -> {
                    pendingFiles.clear()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Eğer flutter engine hazır olmadan önce intent geldiyse bekleyen dosyaları ilet
        if (pendingFiles.isNotEmpty()) {
            val filesToDeliver = ArrayList(pendingFiles)
            flutterEngine.dartExecutor.binaryMessenger.let {
                methodChannel?.invokeMethod("onFilesReceived", filesToDeliver)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return

        val uris = mutableListOf<Uri>()

        if (action == Intent.ACTION_VIEW) {
            intent.data?.let { uris.add(it) }
        } else if (action == Intent.ACTION_SEND) {
            val streamUri = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            } ?: intent.data
            streamUri?.let { uris.add(it) }
        } else if (action == Intent.ACTION_SEND_MULTIPLE) {
            val streamUris = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
            }
            if (streamUris != null) {
                uris.addAll(streamUris)
            }
        }

        if (uris.isEmpty()) return

        val copiedPaths = ArrayList<String>()
        for (uri in uris) {
            val localPath = copyUriToCache(uri)
            if (localPath != null) {
                copiedPaths.add(localPath)
            }
        }

        if (copiedPaths.isNotEmpty()) {
            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod("onFilesReceived", copiedPaths)
            } else {
                pendingFiles.addAll(copiedPaths)
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            var fileName: String? = null
            if (uri.scheme == "content") {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1 && cursor.moveToFirst()) {
                        fileName = cursor.getString(nameIndex)
                    }
                }
            } else if (uri.scheme == "file") {
                fileName = uri.lastPathSegment
            }

            if (fileName.isNullOrBlank()) {
                val mime = contentResolver.getType(uri) ?: "application/octet-stream"
                val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "bin"
                fileName = "incoming_${System.currentTimeMillis()}.$ext"
            }

            // Güvenli dosya adı oluştur (özel karakterleri temizle)
            val safeName = fileName!!.replace("[\\\\/:*?\"<>|]".toRegex(), "_")

            val incomingDir = File(cacheDir, "incoming_files")
            if (!incomingDir.exists()) {
                incomingDir.mkdirs()
            }

            val destFile = File(incomingDir, safeName)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (destFile.exists() && destFile.length() > 0) {
                destFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            android.util.Log.e("FileConverter", "Failed to cache incoming URI: $uri", e)
            null
        }
    }
}