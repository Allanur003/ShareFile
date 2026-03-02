package com.example.secure_share_files

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Method

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.secureshare/native"
    private val HOTSPOT_SSID = "SecureShare_Direct"
    private val HOTSPOT_PASSWORD = "share2024"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableHotspot" -> {
                        enableHotspot()
                        result.success(mapOf("ssid" to HOTSPOT_SSID, "password" to HOTSPOT_PASSWORD))
                    }
                    "disableHotspot" -> {
                        disableHotspot()
                        result.success(true)
                    }
                    "connectToHotspot" -> {
                        connectToWifi(HOTSPOT_SSID, HOTSPOT_PASSWORD)
                        result.success(true)
                    }
                    "getHotspotInfo" -> {
                        result.success(mapOf("ssid" to HOTSPOT_SSID, "password" to HOTSPOT_PASSWORD))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun enableHotspot() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Android 8+ için sistem ayarlarını aç
                val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            } else {
                // Eski Android için reflection kullan
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                val method: Method = wifiManager.javaClass.getMethod(
                    "setWifiApEnabled",
                    WifiConfiguration::class.java,
                    Boolean::class.javaPrimitiveType
                )
                
                val config = WifiConfiguration()
                config.SSID = HOTSPOT_SSID
                config.preSharedKey = HOTSPOT_PASSWORD
                config.allowedAuthAlgorithms.set(WifiConfiguration.AuthAlgorithm.OPEN)
                config.allowedProtocols.set(WifiConfiguration.Protocol.RSN)
                config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                
                method.invoke(wifiManager, config, true)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun disableHotspot() {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                val method: Method = wifiManager.javaClass.getMethod(
                    "setWifiApEnabled",
                    WifiConfiguration::class.java,
                    Boolean::class.javaPrimitiveType
                )
                method.invoke(wifiManager, null, false)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun connectToWifi(ssid: String, password: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ için WiFi ayarlarını aç
                val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            } else {
                // Eski Android için otomatik bağlan
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                
                val config = WifiConfiguration()
                config.SSID = "\"$ssid\""
                config.preSharedKey = "\"$password\""
                config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                
                val netId = wifiManager.addNetwork(config)
                wifiManager.disconnect()
                wifiManager.enableNetwork(netId, true)
                wifiManager.reconnect()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
