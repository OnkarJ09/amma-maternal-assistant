import 'package:amma_app/models/sensor_reading.dart';
import 'package:amma_app/services/maternal_sleep_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaternalSleepService', () {
    const service = MaternalSleepService();

    test('getClinicalSleepReport computes clinical benchmarks from sleeping_front_up.csv', () {
      final report = service.getClinicalSleepReport(sleepHours: 7.8);

      expect(report.healthScore, equals(93));
      expect(report.sleepHours, equals(7.8));
      expect(report.formattedDuration, equals('7h 48m'));
      expect(report.gyroStillnessPercent, equals(91.4));
      expect(report.meanAngularVelocity, equals(0.0987));
      expect(report.posture, equals('Front-Up (Supine)'));
      expect(report.postureAz, equals(10.69));
      expect(report.tossAndTurnShifts, equals(28));
      expect(report.clinicalRating, equals('Optimal Recovery'));
      expect(report.sourceLabel, equals('docs/sensor_data/sleeping_front_up.csv'));
      expect(report.isClinicalBenchmark, isTrue);
    });

    test('calculateFromReadings falls back to clinical benchmark on empty readings', () {
      final report = service.calculateFromReadings([]);
      expect(report.healthScore, equals(93));
      expect(report.gyroStillnessPercent, equals(91.4));
    });

    test('calculateFromReadings computes stillness and health score from stream', () {
      final now = DateTime(2026, 10, 22, 10, 0);
      final readings = [
        SensorReading(
          entryId: 1,
          timestamp: now,
          mlMagnitude: 9.81,
          mrMagnitude: 9.80,
        ),
        SensorReading(
          entryId: 2,
          timestamp: now.add(const Duration(hours: 4)),
          mlMagnitude: 9.82,
          mrMagnitude: 9.81,
        ),
      ];

      final report = service.calculateFromReadings(readings, targetHours: 8.0);
      expect(report.healthScore, isNonZero);
      expect(report.gyroStillnessPercent, equals(91.4));
      expect(report.sleepHours, equals(4.0));
    });
  });
}
