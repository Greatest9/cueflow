import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {
  static Future<String> getHotspotGateway() async {
    final info = NetworkInfo();
    try {
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty) {
        // Common hotspot gateways
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          // Try .1
          final gateway = '${parts[0]}.${parts[1]}.${parts[2]}.1';
          return gateway;
        }
      }
      // Fallbacks
      return '192.168.43.1';
    } catch (e) {
      return '192.168.43.1';
    }
  }
  
  static Future<String> getLocalIp() async {
    final info = NetworkInfo();
    try {
      final ip = await info.getWifiIP();
      return ip ?? '0.0.0.0';
    } catch (e) {
      return '0.0.0.0';
    }
  }
}