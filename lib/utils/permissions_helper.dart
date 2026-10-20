import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionsHelper {
  static Future<bool> requestAll() async {
    if (Platform.isIOS) {
      return true;
    }
    
    final permissions = <Permission>[
      Permission.microphone,
      Permission.notification,
    ];
    
    if (Platform.isAndroid) {
      try {
        await Permission.ignoreBatteryOptimizations.request();
      } catch (_) {}
    }
    
    final statuses = await permissions.request();
    bool allGranted = true;
    
    for (final status in statuses.values) {
      if (!status.isGranted && !status.isLimited) {
        allGranted = false;
      }
    }
    
    return allGranted;
  }
}