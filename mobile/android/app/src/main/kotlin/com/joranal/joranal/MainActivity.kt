package com.journal.journal

import android.net.Uri
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var exportResult: MethodChannel.Result? = null
    private var exportSource: File? = null

    private val createDocument =
        registerForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri: Uri? ->
            val result = exportResult
            val source = exportSource
            exportResult = null
            exportSource = null
            if (result == null) return@registerForActivityResult
            if (uri == null || source == null) {
                result.success(false)
                return@registerForActivityResult
            }
            try {
                contentResolver.openOutputStream(uri)?.use { output ->
                    source.inputStream().use { input -> input.copyTo(output) }
                } ?: run {
                    result.error("export_failed", "Could not write the backup file.", null)
                    return@registerForActivityResult
                }
                result.success(true)
            } catch (error: Exception) {
                result.error("export_failed", error.message, null)
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "journal/file_export")
            .setMethodCallHandler { call, result ->
                if (call.method != "exportFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val name = call.argument<String>("name") ?: "journal-journal-backup.json"
                if (path == null) {
                    result.error("bad_args", "Missing path", null)
                    return@setMethodCallHandler
                }
                val file = File(path)
                if (!file.exists()) {
                    result.error("missing", "Backup file was not found.", null)
                    return@setMethodCallHandler
                }
                if (exportResult != null) {
                    result.error("busy", "A save dialog is already open.", null)
                    return@setMethodCallHandler
                }
                exportResult = result
                exportSource = file
                createDocument.launch(name)
            }
    }
}
