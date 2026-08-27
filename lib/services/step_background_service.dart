import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pedometer/pedometer.dart';

class StepBackgroundService {
  static const _storage = FlutterSecureStorage();

  static Future<void> initialize() async {
    await syncWithSource();
  }

  static Future<void> syncWithSource() async {
    final raw = await _storage.read(key: 'step_source');
    final source = raw ?? 'native_sensor';
    final shouldRun = source == 'native_sensor';
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    // Si no había fuente guardada, persiste el default native_sensor
    if (raw == null) {
      await _storage.write(key: 'step_source', value: 'native_sensor');
    }

    if (!shouldRun) {
      await _storage.write(key: 'scs_mode', value: 'inactive');
      if (isRunning) {
        service.invoke('stopService');
      }
      return;
    }

    await _storage.write(key: 'scs_mode', value: 'background');

    if (isRunning) {
      return;
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: 'walkwin_lockscreen',
        initialNotificationTitle: 'Exploria',
        initialNotificationContent: 'Sumando pasos...',
        foregroundServiceNotificationId: 1,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
      ),
    );

    await service.startService();
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  _BgStepCounter.start(service);
}

class _BgStepCounter {
  static const _storage = FlutterSecureStorage();

  static const _keyMode = 'scs_mode';
  static const _keySensor = 'scs_bg_sensor';
  static const _keyDate = 'scs_bg_date';
  static const _keyDaily = 'scs_bg_daily';
  static const _keyMainSensor = 'scs_last_sensor';
  static const _keyMainDate = 'scs_last_date';
  static const _keyMainDaily = 'scs_session';

  static int? _lastAcceptedSensorValue;
  static DateTime? _lastAcceptedStepTime;
  static String _activeDayKey = '';
  static int _sessionSteps = 0;
  static const int _minStepIntervalMs = 150;

  static DateTime _argentinaNow() {
    return DateTime.now().toUtc().subtract(const Duration(hours: 3));
  }

  static String _argentinaDateKey() {
    final now = _argentinaNow();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> start(ServiceInstance service) async {
    await _storage.write(key: _keyMode, value: 'background');
    final source = await _storage.read(key: 'step_source');
    if (source != null && source != 'native_sensor') {
      await _storage.write(key: _keyMode, value: 'inactive');
      service.stopSelf();
      return;
    }
    await _restorePersistedState();
    _activeDayKey = _argentinaDateKey();
    _initPedometer(service);
    _mirror();
    Timer.periodic(const Duration(seconds: 30), (_) => _mirror());

    // Escuchar reconciliaciones del foreground. Cuando el frontend confirma
    // los pasos con el backend, notifica aquí para que este servicio actualice
    // su _sessionSteps en memoria. Sin esto, el background sobreescribiría el
    // valor reconciliado con su estado interno desactualizado.
    service.on('reconcileSession').listen((data) async {
      final confirmed = (data?['confirmedSteps'] as int?) ?? 0;
      _sessionSteps = math.max(0, confirmed);
      await _persistCurrentState();
    });
  }

  static Future<void> _restorePersistedState() async {
    final sensor = await _storage.read(key: _keySensor);
    final date = await _storage.read(key: _keyDate);
    final daily = await _storage.read(key: _keyDaily);

    _lastAcceptedSensorValue = sensor != null ? int.tryParse(sensor) : null;
    final today = _argentinaDateKey();
    if (date == today) {
      _sessionSteps = daily != null ? int.tryParse(daily) ?? 0 : 0;
    } else {
      _sessionSteps = 0;
      await _storage.write(key: _keyDaily, value: '0');
      await _storage.write(key: _keyDate, value: today);
    }
  }

  static void _initPedometer(ServiceInstance service) {
    Pedometer.stepCountStream.listen(
      (event) => _handleStepEvent(service, event),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  static void _handleStepEvent(ServiceInstance service, StepCount event) {
    final now = DateTime.now();
    final dayKey = _argentinaDateKey();

    if (dayKey != _activeDayKey) {
      final catchUp = _lastAcceptedSensorValue != null
          ? math.max(0, event.steps - _lastAcceptedSensorValue!)
          : 0;

      _activeDayKey = dayKey;
      _lastAcceptedSensorValue = event.steps;
      _lastAcceptedStepTime = now;
      _sessionSteps = catchUp;
      _persistCurrentState();
      service.invoke('stepUpdate', {
        'date': _activeDayKey,
        'sensor': event.steps,
        'daily': _sessionSteps,
      });
      return;
    }

    if (_lastAcceptedSensorValue == null) {
      _lastAcceptedSensorValue = event.steps;
      _lastAcceptedStepTime = now;
      _persistCurrentState();
      return;
    }

    if (_lastAcceptedStepTime != null &&
        now.difference(_lastAcceptedStepTime!).inMilliseconds <
            _minStepIntervalMs) {
      return;
    }

    final delta = event.steps - _lastAcceptedSensorValue!;
    if (delta < 0) {
      _lastAcceptedSensorValue = event.steps;
      _lastAcceptedStepTime = now;
      _persistCurrentState();
      return;
    }

    if (delta > 0) {
      _lastAcceptedSensorValue = event.steps;
      _lastAcceptedStepTime = now;
      _sessionSteps += delta;
      _persistCurrentState();
      service.invoke('stepUpdate', {
        'date': _activeDayKey,
        'sensor': _lastAcceptedSensorValue,
        'daily': _sessionSteps,
      });
    }
  }

  static Future<void> _persistCurrentState() async {
    if (_lastAcceptedSensorValue == null) return;
    await _storage.write(
      key: _keySensor,
      value: _lastAcceptedSensorValue.toString(),
    );
    await _storage.write(key: _keyDate, value: _activeDayKey);
    await _storage.write(key: _keyDaily, value: _sessionSteps.toString());
  }

  static Future<void> _mirror() async {
    final mainVal = await _storage.read(key: _keyMainSensor);
    final mainDate = await _storage.read(key: _keyMainDate);
    final mainDaily = await _storage.read(key: _keyMainDaily);

    final today = _argentinaDateKey();
    if (mainDate != null && mainDate != today) {
      await _storage.write(key: _keyDaily, value: '0');
      await _storage.write(key: _keyMainDaily, value: '0');
      _sessionSteps = 0;
      return;
    }

    if (mainVal != null && mainDate != null && mainDate == today) {
      await _storage.write(key: _keySensor, value: mainVal);
      await _storage.write(key: _keyDate, value: mainDate);
    }
    if (mainDaily != null && mainDate == today) {
      await _storage.write(key: _keyDaily, value: mainDaily);
    }
  }
}
