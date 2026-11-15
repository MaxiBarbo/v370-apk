package com.example.v370_apk

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var backupToWrite: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "v370/backup")
            .setMethodCallHandler { call, result ->
                val request = when (call.method) {
                    "open" -> 7401
                    "save", "saveReport" -> 7402
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                if (pending != null) {
                    result.error("busy", "Hay una operación en curso.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.arguments as? ByteArray
                if (request == 7402 && (bytes == null || bytes.size > MAX_BYTES)) {
                    result.error("size", "Tamaño de copia inválido.", null)
                    return@setMethodCallHandler
                }
                val intent = Intent(
                    if (request == 7401) Intent.ACTION_OPEN_DOCUMENT else Intent.ACTION_CREATE_DOCUMENT
                ).addCategory(Intent.CATEGORY_OPENABLE)
                intent.type = if (request == 7401) "*/*" else if (call.method == "saveReport")
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                else "application/json"
                if (request == 7402) {
                    val time = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.ROOT).format(Date())
                    intent.putExtra(Intent.EXTRA_TITLE, if (call.method == "saveReport") "v370-informe-$time.xlsx" else "v370-copia-$time.json")
                }
                pending = result
                backupToWrite = bytes
                try {
                    startActivityForResult(intent, request)
                } catch (error: Exception) {
                    pending = null
                    backupToWrite = null
                    result.error("picker", "No se pudo abrir el selector de archivos.", null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7401 && requestCode != 7402) return
        val result = pending ?: return
        val bytes = backupToWrite
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null
            backupToWrite = null
            result.success(null)
            return
        }
        Thread {
            try {
                val value: Any = if (requestCode == 7402) {
                    val output = contentResolver.openOutputStream(uri, "wt")
                        ?: throw IOException("No se pudo abrir el destino")
                    output.use { it.write(bytes ?: throw IOException("Copia vacía")) }
                    true
                } else {
                    val input = contentResolver.openInputStream(uri)
                        ?: throw IOException("No se pudo abrir el archivo")
                    input.use {
                        val content = ByteArrayOutputStream()
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            val count = it.read(buffer)
                            if (count == -1) break
                            if (content.size() + count > MAX_BYTES) {
                                throw IOException("La copia supera 32 MB")
                            }
                            content.write(buffer, 0, count)
                        }
                        content.toByteArray()
                    }
                }
                runOnUiThread {
                    pending = null
                    backupToWrite = null
                    result.success(value)
                }
            } catch (error: Exception) {
                runOnUiThread {
                    pending = null
                    backupToWrite = null
                    result.error("io", error.message, null)
                }
            }
        }.start()
    }

    companion object {
        private const val MAX_BYTES = 32 * 1024 * 1024
    }
}
