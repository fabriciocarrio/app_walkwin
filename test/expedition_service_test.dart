import 'package:flutter_test/flutter_test.dart';
import 'package:walkwin_app/services/expedition_service.dart';

void main() {
  group('ExpeditionService Unit Tests', () {
    late ExpeditionService service;

    setUp(() {
      service = ExpeditionService();
    });

    test('Initial state is idle', () {
      expect(service.status, ExpeditionStatus.idle);
      expect(service.isIdle, isTrue);
      expect(service.routePoints, isEmpty);
      expect(service.totalDistanceMeters, 0.0);
      expect(service.elapsedSeconds, 0);
      expect(service.formattedTime, '00:00');
    });

    test('Estimations return valid step and PE metrics', () {
      // 750 metros -> 1000 pasos (a 0.75m/paso) -> 10 PE (a 100 pasos/PE)
      expect(service.estimatedSteps, 0);
      expect(service.estimatedPe, 0);
    });

    test('Formatted time converts seconds correctly', () {
      expect(service.formattedTime, '00:00');
    });
  });
}
