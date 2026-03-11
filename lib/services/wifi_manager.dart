import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:io';

class WiFiManager {
  static const String hotspotPrefix = 'SecureShare_';
  static const String hotspotPassword = 'share12345';
  
  String? _hotspotName;
  
Future<String?> startHotspot() async {
  print("Hotspot'u telefondan manuel açın");
  return null;
}

  Future<void> stopHotspot() async {
    try {
      if (Platform.isAndroid) {
        await WiFiForIoTPlugin.setWiFiAPEnabled(false);
        print('⛔ Hotspot ýapyldy');
      }
      _hotspotName = null;
    } catch (e) {
      print('❌ Hotspot ýapma ýalňyşlygy: $e');
    }
  }

  Future<List<String>> scanNetworks() async {
    try {
      if (!await _requestPermissions()) {
        throw Exception('Gerekli rugsatlar berilmedi');
      }

      final networks = await WiFiForIoTPlugin.loadWifiList();
      
      final secureShareNetworks = networks
          .where((network) => network.ssid?.startsWith(hotspotPrefix) ?? false)
          .map((network) => network.ssid!)
          .toList();

      print('📡 Bulunan SecureShare ağları: $secureShareNetworks');
      return secureShareNetworks;
    } catch (e) {
      print('❌ WiFi gozleme nasazlygy: $e');
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
  joinOnce: true,
);

      if (connected) {
        await Future.delayed(const Duration(seconds: 2));
        final ip = await getConnectedIP();
        print('✅ Bağlandy! IP: $ip');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Bağlanma nasazlygy: $e');
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
        print('❌ Rugsat ýatyryldy: $permission');
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
