import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final Health _health = Health();

  static const _types = [HealthDataType.STEPS];

  /// Request authorization from Google Health Connect / Apple Health.
  ///
  /// Flujo:
  /// 1. Solicita ACTIVITY_RECOGNITION (necesario en Android 10+).
  /// 2. Lanza el diálogo nativo de Health Connect (requiere FlutterFragmentActivity).
  /// 3. Devuelve true solo si el resultado fue positivo.
  ///
  /// NOTA: en Android, `hasPermissions()` siempre devuelve null — limitación
  /// de la API de Health Connect. No intentar leer datos para "verificar" el
  /// permiso porque eso lanza SecurityException si no fue otorgado.
  static Future<bool> requestAuthorization() async {
    // 1. Solicitar permiso de reconocimiento de actividad (Android 10+)
    try {
      await Permission.activityRecognition.request();
    } catch (_) {}

    try {
      // 2. Lanzar el diálogo nativo de Health Connect
      //    Requiere que MainActivity extienda FlutterFragmentActivity
      final granted = await _health.requestAuthorization(
        _types,
        permissions: [HealthDataAccess.READ],
      );
      return granted;
    } catch (_) {
      // Si el diálogo fue bloqueado por el OS (denegado 2 veces),
      // requestAuthorization lanza excepción — devolver false limpiamente
      return false;
    }
  }

  /// Whether Google Health Connect is available on the device.
  /// Always true on iOS (Apple Health is used instead).
  static Future<bool> isHealthConnectAvailable() =>
      _health.isHealthConnectAvailable();

  /// Prompt the user to install Google Health Connect (needed on Android 13-).
  static Future<void> promptInstallHealthConnect() =>
      _health.installHealthConnect();

  /// Open the Health Connect app's permission screen for this app directly.
  /// Usar cuando el OS bloqueó el diálogo por denegaciones previas.
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
  /// ONLY call this after requestAuthorization() returned true.
  static Future<int?> getTodaySteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: _types,
      );
      if (data.isEmpty) return 0;
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
