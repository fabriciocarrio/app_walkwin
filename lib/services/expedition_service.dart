import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Estado actual de la sesión de expedición
enum ExpeditionStatus {
  idle,
  recording,
  paused,
}

/// Contenedor con los resultados consolidados de una expedición finalizada
class ExpeditionResult {
  final List<LatLng> routePoints;
  final double totalDistanceMeters;
  final int elapsedSeconds;
  final int estimatedSteps;
  final int estimatedPe;
  final DateTime startTime;
  final DateTime endTime;

  ExpeditionResult({
    required this.routePoints,
    required this.totalDistanceMeters,
    required this.elapsedSeconds,
    required this.estimatedSteps,
    required this.estimatedPe,
    required this.startTime,
    required this.endTime,
  });

  double get distanceKm => totalDistanceMeters / 1000.0;
}

/// Servicio desacoplado para el seguimiento GPS, cálculo de métricas en tiempo real
/// y filtrado de ruido de posición durante las expediciones de Exploria.
class ExpeditionService extends ChangeNotifier {
  static final ExpeditionService _instance = ExpeditionService._internal();
  factory ExpeditionService() => _instance;
  ExpeditionService._internal();

  ExpeditionStatus _status = ExpeditionStatus.idle;
  ExpeditionStatus get status => _status;

  bool get isIdle => _status == ExpeditionStatus.idle;
  bool get isRecording => _status == ExpeditionStatus.recording;
  bool get isPaused => _status == ExpeditionStatus.paused;

  final List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);

  double _totalDistanceMeters = 0.0;
  double get totalDistanceMeters => _totalDistanceMeters;
  double get totalDistanceKm => _totalDistanceMeters / 1000.0;

  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;

  int get estimatedSteps => (_totalDistanceMeters / 0.75).round();
  int get estimatedPe => (estimatedSteps / 100).floor();

  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastValidPosition;
  DateTime? _startTime;

  // Configuración de precisión y filtrado GPS
  static const double _maxAllowedAccuracyMeters = 30.0; // Descartar si imprecisión > 30m
  static const double _maxAllowedSpeedMps = 8.33; // Descartar si velocidad > 30 km/h (caminando/trotando)

  /// Formateador de tiempo transcurrido (HH:mm:ss o mm:ss)
  String get formattedTime {
    final int hours = _elapsedSeconds ~/ 3600;
    final int minutes = (_elapsedSeconds % 3600) ~/ 60;
    final int seconds = _elapsedSeconds % 60;

    final String mStr = minutes.toString().padLeft(2, '0');
    final String sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final String hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  /// Inicia el seguimiento GPS y el cronómetro de la expedición
  Future<bool> startExpedition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // Resetear datos previas
    _routePoints.clear();
    _totalDistanceMeters = 0.0;
    _elapsedSeconds = 0;
    _startTime = DateTime.now();
    _status = ExpeditionStatus.recording;

    try {
      final Position currentPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (currentPos.accuracy <= _maxAllowedAccuracyMeters) {
        _lastValidPosition = currentPos;
        _routePoints.add(LatLng(currentPos.latitude, currentPos.longitude));
      }
    } catch (_) {
      // Ignorar fallo de primera posición rápida
    }

    _startTimer();
    _startLocationStream();

    notifyListeners();
    return true;
  }

  /// Pausa temporalmente el contador y el stream GPS
  void pauseExpedition() {
    if (_status != ExpeditionStatus.recording) return;

    _status = ExpeditionStatus.paused;
    _timer?.cancel();
    _positionSubscription?.pause();

    notifyListeners();
  }

  /// Reanuda la grabación de la expedición
  void resumeExpedition() {
    if (_status != ExpeditionStatus.paused) return;

    _status = ExpeditionStatus.recording;
    _startTimer();
    _positionSubscription?.resume();

    notifyListeners();
  }

  /// Finaliza la sesión y consolida los resultados en un [ExpeditionResult]
  ExpeditionResult stopExpedition() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    _positionSubscription = null;

    final result = ExpeditionResult(
      routePoints: List.from(_routePoints),
      totalDistanceMeters: _totalDistanceMeters,
      elapsedSeconds: _elapsedSeconds,
      estimatedSteps: estimatedSteps,
      estimatedPe: estimatedPe,
      startTime: _startTime ?? DateTime.now().subtract(Duration(seconds: _elapsedSeconds)),
      endTime: DateTime.now(),
    );

    _status = ExpeditionStatus.idle;
    _lastValidPosition = null;

    notifyListeners();
    return result;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_status == ExpeditionStatus.recording) {
        _elapsedSeconds++;
        notifyListeners();
      }
    });
  }

  void _startLocationStream() {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Notificar cada 5 metros recorridos
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (_status != ExpeditionStatus.recording) return;

      // 1. Filtro de imprecisión GPS
      if (position.accuracy > _maxAllowedAccuracyMeters) {
        return;
      }

      if (_lastValidPosition != null) {
        // 2. Cálculo de distancia incremental
        final double distance = Geolocator.distanceBetween(
          _lastValidPosition!.latitude,
          _lastValidPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        final double timeDiffSeconds =
            position.timestamp.difference(_lastValidPosition!.timestamp).inMilliseconds / 1000.0;

        // 3. Filtro de velocidad irreal (Teletransportación / ruido GPS)
        if (timeDiffSeconds > 0) {
          final double calculatedSpeedMps = distance / timeDiffSeconds;
          if (calculatedSpeedMps > _maxAllowedSpeedMps) {
            return; // Descartar punto por salto irreal de distancia
          }
        }

        if (distance >= 3.0) { // Ignorar micromovimientos < 3 metros
          _totalDistanceMeters += distance;
          _lastValidPosition = position;
          _routePoints.add(LatLng(position.latitude, position.longitude));
          notifyListeners();
        }
      } else {
        _lastValidPosition = position;
        _routePoints.add(LatLng(position.latitude, position.longitude));
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
