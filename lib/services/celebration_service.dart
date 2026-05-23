import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio para reproducir sonidos y vibraciones
/// Configurable desde los ajustes
class CelebrationService {
  static const _storage = FlutterSecureStorage();

  // Claves de almacenamiento
  static const _soundKey = 'celebration_sound_enabled';
  static const _vibrationKey = 'celebration_vibration_enabled';

  // Valores por defecto
  static const _defaultSoundEnabled = true;
  static const _defaultVibrationEnabled = true;

  /// Obtener si el sonido está habilitado
  static Future<bool> isSoundEnabled() async {
    final saved = await _storage.read(key: _soundKey);
    if (saved == null) return _defaultSoundEnabled;
    return saved.toLowerCase() == 'true';
  }

  /// Obtener si la vibración está habilitada
  static Future<bool> isVibrationEnabled() async {
    final saved = await _storage.read(key: _vibrationKey);
    if (saved == null) return _defaultVibrationEnabled;
    return saved.toLowerCase() == 'true';
  }

  /// Habilitar/deshabilitar sonido
  static Future<void> setSoundEnabled(bool enabled) async {
    await _storage.write(key: _soundKey, value: enabled.toString());
  }

  /// Habilitar/deshabilitar vibración
  static Future<void> setVibrationEnabled(bool enabled) async {
    await _storage.write(key: _vibrationKey, value: enabled.toString());
  }

  /// Reproducir sonido de celebración
  static Future<void> playSound() async {
    final enabled = await isSoundEnabled();
    if (!enabled) return;

    try {
      // Usar el sonido del sistema
      // La constante SystemSoundType.click proporciona un sonido simple
      SystemSound.play(SystemSoundType.click);
    } catch (e) {
      print('Error reproduciendo sonido: $e');
    }
  }

  /// Hacer vibrar el dispositivo
  static Future<void> vibrate({
    int duration = 200, // duración en ms
  }) async {
    final enabled = await isVibrationEnabled();
    if (!enabled) return;

    try {
      // Hacer vibrar el dispositivo
      // HapticFeedback proporciona retroalimentación háptica
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('Error vibrando: $e');
    }
  }

  /// Celebración completa: sonido + vibración
  static Future<void> celebrate({
    bool withSound = true,
    bool withVibration = true,
  }) async {
    if (withSound) {
      await playSound();
    }
    if (withVibration) {
      // Vibración simple
      await vibrate(duration: 200);
      // Pequeño retraso
      await Future.delayed(const Duration(milliseconds: 100));
      // Segunda vibración
      await vibrate(duration: 150);
    }
  }
}
