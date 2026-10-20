import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionResult {
  final bool microphone;
  final bool notification;
  final bool batteryExempt;

  const PermissionResult({
    required this.microphone,
    required this.notification,
    required this.batteryExempt,
  });

  bool get allCriticalGranted => microphone;
}

class PermissionsHelper {
  static Future<PermissionResult> requestAll() async {
    if (!Platform.isAndroid) {
      return const PermissionResult(
        microphone: true,
        notification: true,
        batteryExempt: true,
      );
    }

    bool mic = false;
    bool notif = false;
    bool battery = false;

    try {
      final micStatus = await Permission.microphone.request();
      mic = micStatus.isGranted;
    } catch (_) {}

    try {
      final notifStatus = await Permission.notification.request();
      notif = notifStatus.isGranted;
    } catch (_) {}

    try {
      await Permission.camera.request();
    } catch (_) {}

    try {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
      battery = batteryStatus.isGranted;
    } catch (_) {}

    return PermissionResult(
      microphone: mic,
      notification: notif,
      batteryExempt: battery,
    );
  }

  static Future<bool> hasMicrophone() async {
    if (!Platform.isAndroid) return true;
    try {
      return await Permission.microphone.isGranted;
    } catch (_) {
      return false;
    }
  }
}
