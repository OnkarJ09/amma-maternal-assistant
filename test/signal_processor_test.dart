import 'package:amma_app/models/sensor_reading.dart';
import 'package:amma_app/services/signal_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignalProcessor Dual-Sensor Gating & Filtering', () {
    const processor = SignalProcessor();

    test('handles empty readings safely', () {
      final report = processor.analyzeReadings([]);
      expect(report.points, isEmpty);
      expect(report.candidateKickCount, equals(0));
      expect(report.rejectedArtifactCount, equals(0));
      expect(report.motherRestingPercentage, equals(100.0));
    });

    test('accepts transient spike when maternal motion is resting', () {
      final now = DateTime(2026, 10, 14, 10, 0, 0);
      final readings = [
        SensorReading(
          entryId: 1,
          timestamp: now,
          plRaw: 1000.0,
          mlMagnitude: 9.81, // mother resting
        ),
        SensorReading(
          entryId: 2,
          timestamp: now.add(const Duration(seconds: 1)),
          plRaw: 9000.0, // spike
          mlMagnitude: 9.82, // mother resting
        ),
      ];

      final report = processor.analyzeReadings(
        readings,
        piezoThreshold: 4000.0,
        maternalMotionThreshold: 0.40,
      );

      expect(report.points.length, equals(2));
      expect(report.candidateKickCount, equals(1));
      expect(report.rejectedArtifactCount, equals(0));
      expect(report.points[1].isCandidateKick, isTrue);
    });

    test('rejects spike when maternal motion is active', () {
      final now = DateTime(2026, 10, 14, 10, 0, 0);
      final readings = [
        SensorReading(
          entryId: 1,
          timestamp: now,
          plRaw: 1000.0,
          mlMagnitude: 9.81,
        ),
        SensorReading(
          entryId: 2,
          timestamp: now.add(const Duration(seconds: 1)),
          plRaw: 9500.0, // large spike
          mlMagnitude: 11.20, // dynamic motion = 1.40 m/s² > 0.40
        ),
      ];

      final report = processor.analyzeReadings(
        readings,
        piezoThreshold: 4000.0,
        maternalMotionThreshold: 0.40,
      );

      expect(report.candidateKickCount, equals(0));
      expect(report.rejectedArtifactCount, equals(1));
      expect(report.points[1].isCandidateKick, isFalse);
      expect(report.points[1].rejectionReason, contains('Mother active'));
    });

    test('rejects secondary spike within 2-second refractory period', () {
      final now = DateTime(2026, 10, 14, 10, 0, 0);
      final readings = [
        SensorReading(
          entryId: 1,
          timestamp: now,
          plRaw: 1500.0, // baseline
          mlMagnitude: 9.80,
        ),
        SensorReading(
          entryId: 2,
          timestamp: now.add(const Duration(seconds: 1)),
          plRaw: 8000.0, // kick #1 spike
          mlMagnitude: 9.80,
        ),
        SensorReading(
          entryId: 3,
          timestamp: now.add(const Duration(milliseconds: 1800)), // 0.8s later
          plRaw: 8200.0, // secondary ring/rebound within 2s
          mlMagnitude: 9.80,
        ),
        SensorReading(
          entryId: 4,
          timestamp: now.add(const Duration(seconds: 4)),
          plRaw: 1500.0, // returned to baseline
          mlMagnitude: 9.80,
        ),
        SensorReading(
          entryId: 5,
          timestamp: now.add(const Duration(seconds: 5)),
          plRaw: 8500.0, // kick #2 spike (> 2s refractory from kick #1)
          mlMagnitude: 9.80,
        ),
      ];

      final report = processor.analyzeReadings(
        readings,
        piezoThreshold: 3000.0,
        maternalMotionThreshold: 0.50,
      );

      expect(report.candidateKickCount, equals(2));
      expect(report.rejectedArtifactCount, equals(1));
      expect(report.points[1].isCandidateKick, isTrue);
      expect(report.points[2].isCandidateKick, isFalse);
      expect(report.points[2].rejectionReason, contains('Refractory window'));
      expect(report.points[4].isCandidateKick, isTrue);
    });

    test('detects right piezo (PR) kick when left piezo (PL) is quiet', () {
      final now = DateTime(2026, 10, 14, 10, 0, 0);
      final readings = [
        SensorReading(
          entryId: 1,
          timestamp: now,
          plRaw: 800.0,
          prRaw: 600.0,
          mlMagnitude: 9.80,
        ),
        SensorReading(
          entryId: 2,
          timestamp: now.add(const Duration(seconds: 1)),
          plRaw: 850.0, // PL is flat/quiet
          prRaw: 4500.0, // PR shows major right-flank deflection
          mlMagnitude: 9.81,
        ),
      ];

      final report = processor.analyzeReadings(
        readings,
        piezoThreshold: 1800.0,
        maternalMotionThreshold: 0.35,
      );

      expect(report.candidateKickCount, equals(1));
      expect(report.candidateKicksList.length, equals(1));
      expect(report.candidateKicksList.first.dominantChannel, equals(PiezoChannel.right));
      expect(report.points[1].isCandidateKick, isTrue);
    });

    test('correctly identifies resting mother with uncalibrated stationary offset (10.70 m/s²)', () {
      final now = DateTime(2026, 10, 14, 10, 0, 0);
      final readings = [
        SensorReading(
          entryId: 1,
          timestamp: now,
          plRaw: 1200.0,
          mlMagnitude: 10.70, // uncalibrated resting prototype reading
        ),
        SensorReading(
          entryId: 2,
          timestamp: now.add(const Duration(seconds: 1)),
          plRaw: 5500.0, // valid kick pulse
          mlMagnitude: 10.72, // resting jitter of only 0.02 m/s²
        ),
      ];

      final report = processor.analyzeReadings(
        readings,
        piezoThreshold: 1800.0,
        maternalMotionThreshold: 0.35,
      );

      // Must NOT be rejected as "Mother active" because deviation from rolling baseline is only 0.02 m/s²!
      expect(report.candidateKickCount, equals(1));
      expect(report.rejectedArtifactCount, equals(0));
      expect(report.points[1].isMotherResting, isTrue);
      expect(report.points[1].isCandidateKick, isTrue);
    });
  });
}
