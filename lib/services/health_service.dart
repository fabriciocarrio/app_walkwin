import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final Health _health = Health();

  static const _types = [HealthDataType.STEPS];

  /// Request authorization from Google Health Connect / Apple Health.
  static Future<bool> requestAuthorization() async {
    try {
      await Permission.activityRecognition.request();
    } catch (_) {}

    try {
      // Check if already authorized
      final hasPerms = await _health.hasPermissions(_types, permissions: [HealthDataAccess.READ]);
      if (hasPerms == true) {
        return true;
      }

      // Request native authorization dialog
      final result = await _health.requestAuthorization(_types, permissions: [HealthDataAccess.READ]);
      if (result) {
        return true;
      }

      // Re-check permissions after prompt
      final hasPermsAfter = await _health.hasPermissions(_types, permissions: [HealthDataAccess.READ]);
      if (hasPermsAfter == true) {
        return true;
      }

      // Verification check by trying to read steps
      final steps = await getTodaySteps();
      return steps != null;
    } catch (e) {
      try {
        final hasPermsAfter = await _health.hasPermissions(_types, permissions: [HealthDataAccess.READ]);
        if (hasPermsAfter == true) return true;
        final steps = await getTodaySteps();
        return steps != null;
      } catch (_) {
        return false;
      }
    }
  }

  /// Whether Google Health Connect is available on the device.
  /// Always true on iOS (Apple Health is used instead).
  static Future<bool> isHealthConnectAvailable() =>
      _health.isHealthConnectAvailable();

  /// Prompt the user to install Google Health Connect (needed on Android 13-).
  static Future<void> promptInstallHealthConnect() =>
      _health.installHealthConnect();

  /// Get total steps for today from the health platform.
  /// Returns null if unavailable or permission denied.
  static Future<int?> getTodaySteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: _types,
      );
      if (data.isEmpty) return null;
      final deduplicated = _health.removeDuplicates(data);
      int total = 0;
      for (final point in deduplicated) {
        if (point.type == HealthDataType.STEPS) {
          total += (point.value as NumericHealthValue).numericValue.toInt();
        }
      }
      return total;
    } catch (_) {
      return null;
    }
  }
}
