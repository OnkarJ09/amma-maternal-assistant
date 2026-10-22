import 'package:amma_app/models/sensor_reading.dart';
import 'package:amma_app/services/maternal_sleep_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaternalSleepService', () {
    const service = MaternalSleepService();

    test('DailySleepCycle correctly resolves 10 PM to 10 PM cycles', () {
      // 1. Daytime query (10:45 AM on Oct 22): cycle started Oct 21 22:00 and ends Oct 22 22:00
      final morningTime = DateTime(2026, 10, 22, 10, 45);
      final morningCycle = DailySleepCycle.forDateTime(morningTime);
      expect(morningCycle.startTime, equals(DateTime(2026, 10, 21, 22, 0)));
      expect(morningCycle.endTime, equals(DateTime(2026, 10, 22, 22, 0)));
      expect(morningCycle.formattedCycleRange, contains('Oct 21, 10 PM'));
      expect(morningCycle.formattedCycleRange, contains('Oct 22, 10 PM'));

      // 2. Late evening query (10:30 PM on Oct 22): cycle rolled over to Oct 22 22:00 -> Oct 23 22:00
      final eveningTime = DateTime(2026, 10, 22, 22, 30);
      final eveningCycle = DailySleepCycle.forDateTime(eveningTime);
      expect(eveningCycle.startTime, equals(DateTime(2026, 10, 22, 22, 0)));
      expect(eveningCycle.endTime, equals(DateTime(2026, 10, 23, 22, 0)));
      expect(eveningCycle.formattedCycleRange, contains('Oct 22, 10 PM'));
      expect(eveningCycle.formattedCycleRange, contains('Oct 23, 10 PM'));
    });

    test('getClinicalSleepReport computes circadian schedule benchmarks and episodes', () {
      final report = service.getClinicalSleepReport(
        referenceTime: DateTime(2026, 10, 22, 10, 0),
      );

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
      expect(report.postureAz, equals(10.68));
      expect(report.tossAndTurnShifts, equals(28));
      expect(report.clinicalRating, equals('Optimal Circadian Rest'));
      expect(report.sourceLabel, equals('ThingSpeak (3465279)'));
      expect(report.isClinicalBenchmark, isFalse);

      // Verify sleep episodes (From-To and isActuallySleeping)
      expect(report.nightEpisode.fromTime, equals('10:15 PM'));
      expect(report.nightEpisode.toTime, equals('06:30 AM'));
      expect(report.nightEpisode.isActuallySleeping, isTrue);
      expect(report.nightEpisode.actualSleepDurationHours, greaterThan(7.0));

      expect(report.napEpisode.fromTime, equals('01:15 PM'));
      expect(report.napEpisode.toTime, equals('02:30 PM'));
      expect(report.napEpisode.isActuallySleeping, isTrue);
      expect(report.napEpisode.actualSleepDurationHours, greaterThan(1.0));
    });

    test('calculateFromReadings returns offline report with score null and scoreDisplay -- on empty readings', () {
      final report = service.calculateFromReadings([]);
      expect(report.hasData, isFalse);
      expect(report.healthScore, isNull);
      expect(report.scoreDisplay, equals('--'));
      expect(report.isStale, isTrue);
      expect(report.clinicalRating, contains('No Sleep Data (Wearable Offline)'));
      expect(report.nightEpisode.hasRecordedData, isFalse);
      expect(report.napEpisode.hasRecordedData, isFalse);
    });

    test('calculateFromReadings falls back to circadian benchmark when explicitly requested', () {
      final report = service.calculateFromReadings([], fallbackToBenchmark: true);
      expect(report.hasData, isTrue);
      expect(report.healthScore, equals(98));
      expect(report.scoreDisplay, equals('98'));
      expect(report.formattedTotalDuration, equals('9h 30m'));
      expect(report.gyroStillnessPercent, equals(91.4));
      expect(report.nightEpisode.isActuallySleeping, isTrue);
      expect(report.napEpisode.isActuallySleeping, isTrue);
    });

    test('calculateFromReadings marks report as offline/stale when telemetry is 16h old', () {
      // Last reading 16 hours ago at 6:56 PM yesterday (Oct 21 18:56)
      final staleReading = SensorReading(
        entryId: 570,
        timestamp: DateTime(2026, 10, 21, 18, 56),
        mlMagnitude: 9.80,
      );
      final report = service.calculateFromReadings(
        [staleReading],
        referenceTime: DateTime(2026, 10, 22, 11, 0),
      );
      expect(report.hasData, isFalse);
      expect(report.healthScore, isNull);
      expect(report.scoreDisplay, equals('--'));
      expect(report.isStale, isTrue);
      expect(report.staleHours, greaterThan(15.0));
      expect(report.clinicalRating, contains('Wearable Offline'));
      expect(report.clinicalNotes, contains('offline'));
    });

    test('calculateFromReadings applies penalty when sleep occurs after 3:30 PM alongside active cycle readings', () {
      final cycleStart = DateTime(2026, 10, 21, 23, 0); // 11:00 PM night sleep
      final lateTime = DateTime(2026, 10, 22, 16, 0); // 4:00 PM (restricted zone)

      // Provide night sleep readings so hasNightData is true
      final nightReadings = List.generate(
        30,
        (i) => SensorReading(
          entryId: i + 1,
          timestamp: cycleStart.add(Duration(minutes: i * 10)),
          mlMagnitude: 10.68, // Front-up resting
          mrMagnitude: 9.80,
        ),
      );

      // Provide late sleep readings after 3:30 PM
      final lateReadings = List.generate(
        30,
        (i) => SensorReading(
          entryId: 100 + i,
          timestamp: lateTime.add(Duration(seconds: i * 20)),
          mlMagnitude: 10.68,
          mrMagnitude: 9.80,
        ),
      );

      final report = service.calculateFromReadings(
        [...nightReadings, ...lateReadings],
        referenceTime: DateTime(2026, 10, 22, 17, 0),
      );
      expect(report.hasData, isTrue);
      expect(report.lateSleepHours, greaterThan(0.0));
      expect(report.healthScore, lessThan(98));
      expect(report.clinicalNotes, contains('Late sleep after 3:30 PM detected'));
    });
  });
}
