import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {
  static Future<String> getHotspotGateway() async {
    final info = NetworkInfo();
    try {
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty) {
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          return '${parts[0]}.${parts[1]}.${parts[2]}.1';
        }
      }
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

  /// Returns the device's real LAN IPv4 address by inspecting interfaces,
  /// or null if none is available.
  static Future<String?> getLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip == '0.0.0.0' || ip.startsWith('127.')) continue;
          return ip;
        }
      }
    } catch (_) {}
    return null;
  }

  static bool isValidLanIp(String ip) {
    if (ip.isEmpty || ip == '0.0.0.0' || ip.startsWith('127.')) return false;
    final parts = ip.split('.');
    return parts.length == 4;
  }
}
