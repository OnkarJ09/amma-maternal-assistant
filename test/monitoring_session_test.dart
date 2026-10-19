import 'package:amma_app/models/monitoring_session.dart';
import 'package:amma_app/models/sensor_reading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonitoringSession', () {
    test('calculates duration, sample count, and peaks accurately', () {
      final start = DateTime(2026, 10, 14, 10, 0, 0);
      final end = DateTime(2026, 10, 14, 11, 30, 0);

      final r1 = SensorReading(
        entryId: 1,
        timestamp: start,
        plRaw: 1200,
        prRaw: 400,
        mlMagnitude: 9.8,
        mrMagnitude: 9.7,
      );

      final r2 = SensorReading(
        entryId: 2,
        timestamp: start.add(const Duration(seconds: 20)),
        plRaw: 4500,
        prRaw: 800,
        mlMagnitude: 10.5,
        mrMagnitude: 9.9,
      );

      final session = MonitoringSession(
        id: 'TEST-SESSION-001',
        startTime: start,
        endTime: end,
        initialReadings: [r1, r2],
      );

      expect(session.duration, const Duration(minutes: 90));
      expect(session.sampleCount, 2);
      expect(session.peakPlRaw, 4500);
      expect(session.peakPrRaw, 800);
      expect(session.peakMlMagnitude, 10.5);
      expect(session.peakMrMagnitude, 9.9);
    });

    test('generates valid RFC-4180 CSV telemetry output', () {
      final start = DateTime.utc(2026, 10, 14, 10, 0, 0);
      final r1 = SensorReading(
        entryId: 101,
        timestamp: start,
        plRaw: 2000,
        prRaw: 500,
        mlMagnitude: 9.81,
        mrMagnitude: 9.80,
        mlX: 0.1,
        mlY: 0.2,
        mrX: -0.1,
        mrY: -0.2,
      );

      final session = MonitoringSession(
        id: 'TEST-CSV-001',
        startTime: start,
        initialReadings: [r1],
      );

      final csv = session.toCsv();
      expect(csv, contains('Entry_ID,Timestamp_UTC,PL_Raw_ADC'));
      expect(csv, contains('101,"2026-10-14 10:00:00",2000'));
      expect(csv, contains('9.81,9.8,0.1,0.2,-0.1,-0.2'));
    });
  });
}
