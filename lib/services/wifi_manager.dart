import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:io';

class WiFiManager {
  static const String hotspotPrefix = 'SecureShare_';
  static const String hotspotPassword = 'share12345';
  
  String? _hotspotName;
  
  Future<String?> startHotspot() async {
    try {
      if (!await _requestPermissions()) {
        throw Exception('Gerekli izinler verilmedi');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      _hotspotName = '$hotspotPrefix$timestamp';

      if (Platform.isAndroid) {
        final isStarted = await WiFiForIoTPlugin.setWiFiAPEnabled(true);
        
        if (isStarted) {
          await WiFiForIoTPlugin.setWiFiAPSSID(_hotspotName!);
          await WiFiForIoTPlugin.setWiFiAPPreSharedKey(hotspotPassword);
          
          print('✅ Hotspot açıldı: $_hotspotName');
          return _hotspotName;
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Hotspot hatası: $e');
      return null;
    }
  }

  Future<void> stopHotspot() async {
    try {
      if (Platform.isAndroid) {
        await WiFiForIoTPlugin.setWiFiAPEnabled(false);
        print('⛔ Hotspot kapatıldı');
      }
      _hotspotName = null;
    } catch (e) {
      print('❌ Hotspot kapatma hatası: $e');
    }
  }

  Future<List<String>> scanNetworks() async {
    try {
      if (!await _requestPermissions()) {
        throw Exception('Gerekli izinler verilmedi');
      }

      final networks = await WiFiForIoTPlugin.loadWifiList();
      
      final secureShareNetworks = networks
          .where((network) => network.ssid?.startsWith(hotspotPrefix) ?? false)
          .map((network) => network.ssid!)
          .toList();

      print('📡 Bulunan SecureShare ağları: $secureShareNetworks');
      return secureShareNetworks;
    } catch (e) {
      print('❌ WiFi tarama hatası: $e');
      return [];
    }
  }

  Future<bool> connectToNetwork(String ssid) async {
    try {
      if (!await _requestPermissions()) {
        return false;
      }

      print('🔌 Bağlanılıyor: $ssid');
      
      final connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: hotspotPassword,
        security: NetworkSecurity.WPA,
      );

      if (connected) {
        await Future.delayed(const Duration(seconds: 2));
        final ip = await getConnectedIP();
        print('✅ Bağlandı! IP: $ip');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Bağlantı hatası: $e');
      return false;
    }
  }

  Future<String?> getConnectedIP() async {
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      return wifiIP;
    } catch (e) {
      print('❌ IP alma hatası: $e');
      return null;
    }
  }

  String getHotspotIP() {
    return '192.168.43.1';
  }

  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationWhenInUse,
    ];

    for (var permission in permissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        print('❌ İzin reddedildi: $permission');
        return false;
      }
    }

    return true;
  }

  Future<bool> isHotspotEnabled() async {
    try {
      return await WiFiForIoTPlugin.isWiFiAPEnabled() ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<int> getConnectedDeviceCount() async {
    try {
      final clients = await WiFiForIoTPlugin.getClientList(false, 300);
      return clients?.length ?? 0;
    } catch (e) {
      return 0;
    }
  }

  String? get hotspotName => _hotspotName;
}