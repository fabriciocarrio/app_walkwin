import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final Health _health = Health();

  static const _types = [HealthDataType.STEPS];

  /// Request authorization from Google Fit / Apple Health.
  static Future<bool> requestAuthorization() async {
    await Permission.activityRecognition.request();
    return _health.requestAuthorization(_types, permissions: [HealthDataAccess.READ]);
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
