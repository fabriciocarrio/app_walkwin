import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final Health _health = Health();

  static const _types = [HealthDataType.STEPS];

  /// Request authorization from Google Health Connect / Apple Health.
  /// On Android, this launches the Health Connect system dialog directly.
  /// On repeated denial, opens Health Connect settings so the user can
  /// manually grant access without leaving to the phone Settings.
  static Future<bool> requestAuthorization() async {
    // 1. Request ACTIVITY_RECOGNITION first (needed on Android 10+)
    try {
      await Permission.activityRecognition.request();
    } catch (_) {}

    try {
      // 2. Check if already authorized — skip dialog if so
      final hasPerms = await _health.hasPermissions(
        _types,
        permissions: [HealthDataAccess.READ],
      );
      if (hasPerms == true) return true;

      // 3. Launch the native Health Connect permission dialog
      final granted = await _health.requestAuthorization(
        _types,
        permissions: [HealthDataAccess.READ],
      );

      // 4. Double-check via hasPermissions (HC sometimes returns false even
      //    when the user actually granted access — known upstream issue)
      if (granted) return true;

      final confirmedAfter = await _health.hasPermissions(
        _types,
        permissions: [HealthDataAccess.READ],
      );
      if (confirmedAfter == true) return true;

      // 5. Fallback: try to actually read steps — if it works, we have access
      final steps = await getTodaySteps();
      return steps != null;
    } catch (_) {
      // If requestAuthorization throws (e.g. dialog already blocked by OS),
      // try reading data; if successful, permission was already granted.
      try {
        final hasPerms = await _health.hasPermissions(
          _types,
          permissions: [HealthDataAccess.READ],
        );
        if (hasPerms == true) return true;
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

  /// Open the Health Connect app's permission screen for this app.
  /// Use this when the OS has blocked showing the system dialog (denied twice).
  static Future<void> openHealthConnectSettings() async {
    try {
      await _health.requestAuthorization(
        _types,
        permissions: [HealthDataAccess.READ],
      );
    } catch (_) {}
  }

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
