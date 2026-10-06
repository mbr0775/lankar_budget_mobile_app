package com.tokilo.lankar

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val saveRequestCode = 8041

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tokilo.lankar/reports")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePdf") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSave != null) {
                    result.error("save_busy", "A save is already in progress.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")
                if (bytes == null || name.isNullOrBlank()) {
                    result.error("invalid_report", "Report data is missing.", null)
                    return@setMethodCallHandler
                }
                pendingSave = result
                pendingBytes = bytes
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    startActivityForResult(intent, saveRequestCode)
                } catch (error: Exception) {
                    pendingSave = null
                    pendingBytes = null
                    result.error("save_unavailable", "Could not open the save dialog.", null)
                }
            }
    }

    @Deprecated("Android document picker callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequestCode) return
        val result = pendingSave ?: return
        val bytes = pendingBytes
        pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            pendingSave = null
            result.success(null)
            return
        }
        Thread {
            try {
                val stream = contentResolver.openOutputStream(uri, "w")
                    ?: throw java.io.IOException("Could not open document")
                stream.use { it.write(bytes) }
                runOnUiThread {
                    pendingSave = null
                    result.success(uri.toString())
                }
            } catch (error: Exception) {
                runOnUiThread {
                    pendingSave = null
                    result.error("save_failed", "Could not save the report.", null)
                }
            }
        }.start()
    }
}
