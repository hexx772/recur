package com.appsub.appsub

import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity нужна пакету local_auth (блокировка приложения).
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // БЕТА: чтение входящих SMS для поиска подписок. Читает только
        // за последние `days` дней, ничего не сохраняет и не отправляет.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "appsub/sms")
            .setMethodCallHandler { call, result ->
                if (call.method != "readSms") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val days = call.argument<Int>("days") ?: 180
                val limit = call.argument<Int>("limit") ?: 1000
                try {
                    result.success(readInbox(days, limit))
                } catch (e: SecurityException) {
                    result.error("NO_PERMISSION", "Нет доступа к SMS", null)
                } catch (e: Exception) {
                    result.error("READ_FAILED", e.message, null)
                }
            }
    }

    private fun readInbox(days: Int, limit: Int): List<Map<String, Any?>> {
        val since = System.currentTimeMillis() - days * 24L * 60 * 60 * 1000
        val out = ArrayList<Map<String, Any?>>()
        contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("address", "body", "date"),
            "date >= ?",
            arrayOf(since.toString()),
            "date DESC",
        )?.use { c ->
            val a = c.getColumnIndexOrThrow("address")
            val b = c.getColumnIndexOrThrow("body")
            val d = c.getColumnIndexOrThrow("date")
            while (c.moveToNext() && out.size < limit) {
                out.add(
                    mapOf(
                        "address" to c.getString(a),
                        "body" to c.getString(b),
                        "date" to c.getLong(d),
                    )
                )
            }
        }
        return out
    }
}
