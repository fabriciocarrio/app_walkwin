import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pedometer/pedometer.dart';

class StepCountingService {
  StepCountingService._();
  static final StepCountingService instance = StepCountingService._();

  StreamSubscription<StepCount>? _stepSub;

  int? _lastAcceptedSensorValue;
  DateTime? _lastAcceptedStepTime;
  static const int _minStepIntervalMs = 150;
  String _activeDayKey = '';
  String _stepSource = 'native_sensor';
  static const _storage = FlutterSecureStorage();

  static const _keyLastSensorValue = 'scs_last_sensor';
  static const _keyLastSensorDate = 'scs_last_date';
  static const _keySessionSteps = 'scs_session';
  static const _keyBgSensor = 'scs_bg_sensor';
  static const _keyBgDate = 'scs_bg_date';
  static const _keyBgDaily = 'scs_bg_daily';

  final ValueNotifier<int> sessionStepsNotifier = ValueNotifier(0);
  final ValueNotifier<bool> isRunning = ValueNotifier(false);

  VoidCallback? onStepCounted;
  VoidCallback? onMidnightReset;

  DateTime _argentinaNow() {
    return DateTime.now().toUtc().subtract(const Duration(hours: 3));
  }

  String _argentinaDateKey() {
    final now = _argentinaNow();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Timer? _mirrorTimer;
  bool _backgroundMode = false;

  Future<void> initialize() async {
    await refreshMode();
  }

  Future<void> refreshMode() async {
    _stepSub?.cancel();
    _stepSub = null;
    _mirrorTimer?.cancel();

    final saved = await _storage.read(key: 'step_source');
    if (saved != null) _stepSource = saved;
    _backgroundMode = await FlutterBackgroundService().isRunning();
    await _restorePersistedState();
    _activeDayKey = _argentinaDateKey();

    if (_stepSource != 'native_sensor') {
      isRunning.value = false;
      return;
    }

    if (_backgroundMode) {
      _startMirrorTimer();
    } else {
      _initPedometer();
    }
  }

  void _startMirrorTimer() {
    _mirrorTimer?.cancel();
    _mirrorFromBackground();
    _mirrorTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _mirrorFromBackground();
    });
  }

  Future<void> _mirrorFromBackground() async {
    final bgVal = await _storage.read(key: _keyBgSensor);
    final bgDate = await _storage.read(key: _keyBgDate);
    final bgDaily = await _storage.read(key: _keyBgDaily);

    if (bgVal == null || bgDate == null) return;

    final nextSensor = int.tryParse(bgVal);
    final nextSession = bgDaily != null ? int.tryParse(bgDaily) : null;
    if (nextSensor == null) return;

    final currentDayKey = _argentinaDateKey();
    if (bgDate != _activeDayKey && bgDate == currentDayKey) {
      _activeDayKey = bgDate;
      _lastAcceptedSensorValue = nextSensor;
      _lastAcceptedStepTime = DateTime.now();
      sessionStepsNotifier.value = math.max(0, nextSession ?? 0);
      isRunning.value = sessionStepsNotifier.value > 0;
      await _persistCurrentState();
      onMidnightReset?.call();
      return;
    }

    if (sessionStepsNotifier.value != math.max(0, nextSession ?? 0)) {
      sessionStepsNotifier.value = math.max(0, nextSession ?? 0);
      isRunning.value = sessionStepsNotifier.value > 0;
      _lastAcceptedSensorValue = nextSensor;
      _lastAcceptedStepTime = DateTime.now();
      await _persistCurrentState();
      onStepCounted?.call();
    }
  }

  Future<void> _restorePersistedState() async {
    int? restoredVal;
    String? restoredDate;
    int? restoredSession;

    final mainVal = await _storage.read(key: _keyLastSensorValue);
    final mainDate = await _storage.read(key: _keyLastSensorDate);
    final bgVal = await _storage.read(key: _keyBgSensor);
    final bgDate = await _storage.read(key: _keyBgDate);

    final mainInt = mainVal != null ? int.tryParse(mainVal) : null;
    final bgInt = bgVal != null ? int.tryParse(bgVal) : null;

    final today = _argentinaDateKey();

    // Determinar qué fuente usar: preferir la fecha de hoy,
    // luego el valor más alto si ambas son del mismo día.
    bool useMain = false;
    bool useBg = false;

    if (mainInt != null && mainInt > 0 && bgInt != null && bgInt > 0) {
      if (mainDate == today && bgDate != today) {
        useMain = true;
      } else if (bgDate == today && mainDate != today) {
        useBg = true;
      } else {
        if (bgInt > mainInt) {
          useBg = true;
        } else {
          useMain = true;
        }
      }
    } else if (mainInt != null && mainInt > 0) {
      useMain = true;
    } else if (bgInt != null && bgInt > 0) {
      useBg = true;
    }

    if (useMain) {
      restoredVal = mainInt;
      restoredDate = mainDate;
      if (mainDate == today) {
        final s = await _storage.read(key: _keySessionSteps);
        restoredSession = s != null ? int.tryParse(s) : null;
      }
    } else if (useBg) {
      restoredVal = bgInt;
      restoredDate = bgDate;
      if (bgDate == today) {
        final d = await _storage.read(key: _keyBgDaily);
        restoredSession = d != null ? int.tryParse(d) : null;
      }
    }

    if (restoredVal != null) {
      _lastAcceptedSensorValue = restoredVal;
      if (restoredDate == today &&
          restoredSession != null &&
          restoredSession > 0) {
        sessionStepsNotifier.value = restoredSession;
        isRunning.value = true;
      }
    }
  }

  Future<void> _persistCurrentState() async {
    if (_lastAcceptedSensorValue != null) {
      await _storage.write(
        key: _keyLastSensorValue,
        value: _lastAcceptedSensorValue.toString(),
      );
      await _storage.write(key: _keyLastSensorDate, value: _activeDayKey);
      await _storage.write(
        key: _keySessionSteps,
        value: sessionStepsNotifier.value.toString(),
      );
    }
  }

  Future<void> reloadSource() async {
    final saved = await _storage.read(key: 'step_source');
    if (saved != null) _stepSource = saved;
  }

  void _initPedometer() {
    _stepSub = Pedometer.stepCountStream.listen(
      _handleStepEvent,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void _handleStepEvent(StepCount event) {
    final now = DateTime.now();
    final dayKey = _argentinaDateKey();

    if (dayKey != _activeDayKey) {
      final catchUp = _lastAcceptedSensorValue != null
          ? math.max(0, event.steps - _lastAcceptedSensorValue!)
          : 0;

      _activeDayKey = dayKey;
      _lastAcceptedSensorValue = event.steps;
      _lastAcceptedStepTime = now;
      sessionStepsNotifier.value = catchUp;
      isRunning.value = catchUp > 0;

      _persistCurrentState();
      onMidnightReset?.call();
      if (catchUp > 0) onStepCounted?.call();
      return;
    }

    if (_stepSource != 'native_sensor') return;

    if (_lastAcceptedSensorValue == null) {
      _lastAcceptedSensorValue = event.steps;
      _lastAcceptedStepTime = now;
      _persistCurrentState();
      return;
    }

    if (_lastAcceptedStepTime != null) {
      final msSinceLast = now.difference(_lastAcceptedStepTime!).inMilliseconds;
      if (msSinceLast < _minStepIntervalMs) return;
    }

    final sensorDelta = event.steps - _lastAcceptedSensorValue!;

    if (sensorDelta < 0) {
      _lastAcceptedSensorValue = event.steps;
      _lastAcceptedStepTime = now;
      _persistCurrentState();
      return;
    }

    if (sensorDelta > 0) {
      _lastAcceptedSensorValue = event.steps;
      _lastAcceptedStepTime = now;
      sessionStepsNotifier.value += sensorDelta;
      isRunning.value = true;
      _persistCurrentState();
      onStepCounted?.call();
    }
  }

  Future<void> reduceSessionSteps(int amount) async {
    sessionStepsNotifier.value = math.max(0, sessionStepsNotifier.value - amount);
    isRunning.value = sessionStepsNotifier.value > 0;
    await _persistCurrentState();

    // Keep background mirror keys in sync to avoid restoring stale values.
    await _storage.write(key: _keyBgDate, value: _activeDayKey);
    await _storage.write(
      key: _keyBgDaily,
      value: sessionStepsNotifier.value.toString(),
    );
    if (_lastAcceptedSensorValue != null) {
      await _storage.write(
        key: _keyBgSensor,
        value: _lastAcceptedSensorValue.toString(),
      );
    }
  }

  /// Establece de forma ABSOLUTA cuántos pasos quedan pendientes de confirmación
  /// por el backend. Llamar este método después de recibir `today_steps` de la API
  /// garantiza que nunca se dupliquen pasos, ya que el cálculo es:
  ///   pendingSteps = max(0, totalLocalHoy - backendConfirmadoHoy)
  ///
  /// También notifica al background service para que sincronice su propio
  /// estado en memoria (soluciona la race condition entre foreground y background).
  Future<void> setConfirmedSession(int pendingSteps) async {
    sessionStepsNotifier.value = math.max(0, pendingSteps);
    isRunning.value = sessionStepsNotifier.value > 0;
    await _persistCurrentState();

    // Sincronizar claves del mirror del background
    await _storage.write(key: _keyBgDate, value: _activeDayKey);
    await _storage.write(
      key: _keyBgDaily,
      value: sessionStepsNotifier.value.toString(),
    );
    if (_lastAcceptedSensorValue != null) {
      await _storage.write(
        key: _keyBgSensor,
        value: _lastAcceptedSensorValue.toString(),
      );
    }

    // Notificar al background service para que actualice su _sessionSteps en memoria.
    // Esto evita que el background sobreescriba el valor reconciliado con su
    // estado interno desactualizado (race condition principal del bug).
    try {
      FlutterBackgroundService().invoke('reconcileSession', {
        'confirmedSteps': sessionStepsNotifier.value,
      });
    } catch (_) {
      // El servicio puede no estar corriendo; no es un error crítico.
    }
  }

  void resetSession() {
    _lastAcceptedStepTime = null;
    sessionStepsNotifier.value = 0;
    _persistCurrentState();
  }

  void dispose() {
    _stepSub?.cancel();
    _mirrorTimer?.cancel();
    sessionStepsNotifier.dispose();
    isRunning.dispose();
  }
}
