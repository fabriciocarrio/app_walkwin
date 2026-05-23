import 'package:flutter/services.dart';
import 'dart:async';

/// Servicio para actualizar el lock screen widget con información de pasos y monedas
class LockScreenWidgetService {
  static const platform = MethodChannel('com.walkwin.app/widget');
  static Timer? _updateTimer;

  /// Inicializa el servicio de lock screen widget
  static Future<void> initialize() async {
    try {
      await platform.invokeMethod('initWidget');
    } on PlatformException catch (e) {
      print('Error inicializando lock screen widget: ${e.message}');
    }
  }

  /// Actualiza el lock screen widget con nuevos datos
  static Future<void> updateWidget({
    required int steps,
    required int coins,
  }) async {
    try {
      await platform.invokeMethod('updateWidget', {
        'steps': steps,
        'coins': coins,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      print('Error actualizando lock screen widget: ${e.message}');
    }
  }

  /// Inicia actualizaciones periódicas del widget
  /// [intervalSeconds] es el intervalo de actualización en segundos
  static void startPeriodicUpdates({
    required Function(int steps, int coins) onUpdate,
    int intervalSeconds = 60,
  }) {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(Duration(seconds: intervalSeconds), (
      _,
    ) async {
      // Aquí se obtendría la data actual
      // Por ahora es un placeholder
    });
  }

  /// Detiene las actualizaciones periódicas
  static void stopPeriodicUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Limpia el widget del lock screen
  static Future<void> clearWidget() async {
    try {
      await platform.invokeMethod('clearWidget');
      stopPeriodicUpdates();
    } on PlatformException catch (e) {
      print('Error limpiando lock screen widget: ${e.message}');
    }
  }
}
