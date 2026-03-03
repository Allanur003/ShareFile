package com.example.secure_share_files

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Method

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.secureshare/native"
    private val HOTSPOT_SSID = "SecureShare_Direct"
    private val HOTSPOT_PASSWORD = "share2024"
    private val PERMISSION_REQUEST_CODE = 1001

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableHotspot" -> {
                        enableHotspot()
                        result.success(mapOf(
                            "ssid" to HOTSPOT_SSID,
                            "password" to HOTSPOT_PASSWORD
                        ))
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
                        result.success(mapOf(
                            "ssid" to HOTSPOT_SSID,
                            "password" to HOTSPOT_PASSWORD
                        ))
                    }
                    "requestAllPermissions" -> {
                        requestAllPermissions()
                        result.success(true)
                    }
                    "openStorageSettings" -> {
                        openStorageSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestAllPermissions() {
        val permissions = mutableListOf<String>()

        // Konum izinleri (WiFi için gerekli)
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        // Kamera
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) 
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.CAMERA)
        }

        // Depolama (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) 
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.READ_MEDIA_IMAGES)
                permissions.add(Manifest.permission.READ_MEDIA_VIDEO)
                permissions.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) 
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
                permissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            }
        }

        // Nearby WiFi (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, "android.permission.NEARBY_WIFI_DEVICES") 
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add("android.permission.NEARBY_WIFI_DEVICES")
            }
        }

        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissions.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun openStorageSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+ için özel ayar
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            } else {
                // Eski Android için normal ayarlar
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun enableHotspot() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Android 8+ için ayarları aç
                val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            } else {
                // Eski Android için reflection
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

                wifiManager.isWifiEnabled = false
                Thread.sleep(500)
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
                // Android 10+ için WifiNetworkSpecifier
                val specifier = WifiNetworkSpecifier.Builder()
                    .setSsid(ssid)
                    .setWpa2Passphrase(password)
                    .build()

                val request = NetworkRequest.Builder()
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                    .setNetworkSpecifier(specifier)
                    .build()

                val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                connectivityManager.requestNetwork(request, object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: android.net.Network) {
                        super.onAvailable(network)
                        connectivityManager.bindProcessToNetwork(network)
                    }
                })
            } else {
                // Eski Android için
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

                val config = WifiConfiguration()
                config.SSID = "\"$ssid\""
                config.preSharedKey = "\"$password\""
                config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)

                wifiManager.isWifiEnabled = true
                Thread.sleep(500)

                val netId = wifiManager.addNetwork(config)
                wifiManager.disconnect()
                wifiManager.enableNetwork(netId, true)
                wifiManager.reconnect()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            // Hata varsa WiFi ayarlarını aç
            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        }
    }
}
