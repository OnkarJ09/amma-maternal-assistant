import 'package:amma_app/models/sensor_reading.dart';
import 'package:amma_app/services/maternal_sleep_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaternalSleepService', () {
    const service = MaternalSleepService();

    test('getClinicalSleepReport computes circadian schedule benchmarks', () {
      final report = service.getClinicalSleepReport();

      expect(report.healthScore, equals(98));
      expect(report.nightSleepHours, equals(8.25));
      expect(report.napHours, equals(1.25));
      expect(report.lateSleepHours, equals(0.0));
      expect(report.formattedNightDuration, equals('8h 15m'));
      expect(report.formattedNapDuration, equals('1h 15m'));
      expect(report.formattedTotalDuration, equals('9h 30m'));
      expect(report.gyroStillnessPercent, equals(91.4));
      expect(report.meanAngularVelocity, equals(0.0987));
      expect(report.posture, equals('Front-Up (Supine)'));
      expect(report.postureAz, equals(10.69));
      expect(report.tossAndTurnShifts, equals(28));
      expect(report.clinicalRating, equals('Optimal Circadian Rest'));
      expect(report.sourceLabel, equals('docs/sensor_data/sleeping_front_up.csv'));
      expect(report.isClinicalBenchmark, isTrue);
    });

    test('calculateFromReadings falls back to circadian benchmark on empty readings', () {
      final report = service.calculateFromReadings([]);
      expect(report.healthScore, equals(98));
      expect(report.formattedTotalDuration, equals('9h 30m'));
      expect(report.gyroStillnessPercent, equals(91.4));
    });

    test('calculateFromReadings applies penalty when sleep occurs after 3:30 PM', () {
      final lateTime = DateTime(2026, 10, 22, 16, 0); // 4:00 PM (restricted zone)
      final readings = List.generate(
        25,
        (i) => SensorReading(
          entryId: i + 1,
          timestamp: lateTime.add(Duration(seconds: i * 15)),
          mlMagnitude: 9.80,
          mrMagnitude: 9.80,
        ),
      );

      final report = service.calculateFromReadings(readings);
      expect(report.lateSleepHours, greaterThan(0.0));
      expect(report.healthScore, lessThan(98));
      expect(report.clinicalNotes, contains('Late sleep after 3:30 PM detected'));
    });
  });
}
