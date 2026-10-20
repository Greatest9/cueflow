import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:android_intent_plus/android_intent.dart';

class NetworkService {
  static Future<bool> isWifiConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  static Stream<bool> wifiStateStream() {
    return Connectivity().onConnectivityChanged.map(
          (results) =>
              results.contains(ConnectivityResult.wifi) ||
              results.contains(ConnectivityResult.ethernet),
        );
  }

  static Future<void> openHotspotSettings() async {
    if (!Platform.isAndroid) return;
    try {
      const intent = AndroidIntent(
        action: 'android.settings.TETHER_SETTINGS',
      );
      await intent.launch();
    } catch (_) {
      try {
        const fallback = AndroidIntent(
          action: 'android.settings.WIRELESS_SETTINGS',
        );
        await fallback.launch();
      } catch (_) {}
    }
  }

  static Future<void> openWifiSettings() async {
    if (!Platform.isAndroid) return;
    try {
      const intent = AndroidIntent(
        action: 'android.settings.WIFI_SETTINGS',
      );
      await intent.launch();
    } catch (_) {}
  }
}
