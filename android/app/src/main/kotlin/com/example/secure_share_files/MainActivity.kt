package com.example.secure_share_files

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SETTINGS_CHANNEL = "com.secureshare/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openTethering" -> {
                        try {
                            // Android Hotspot/Tethering ayarlarını aç
                            val intent = Intent()
                            intent.setClassName(
                                "com.android.settings",
                                "com.android.settings.TetherSettings"
                            )
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                // Alternatif yöntem
                                val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
                                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(intent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("ERROR", e2.message, null)
                            }
                        }
                    }
                    "openWifi" -> {
                        try {
                            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
