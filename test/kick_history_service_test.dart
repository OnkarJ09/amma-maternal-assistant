import 'package:amma_app/models/sensor_reading.dart';
import 'package:amma_app/services/kick_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KickHistoryService', () {
    final service = KickHistoryService();

    test('calculates day, week, month summaries with live readings recorded today', () {
      final now = DateTime.now();
      final readings = [
        SensorReading(
          entryId: 1,
          timestamp: now.subtract(const Duration(seconds: 10)),
          plRaw: 1200.0,
          mlMagnitude: 9.80,
        ),
        SensorReading(
          entryId: 2,
          timestamp: now.subtract(const Duration(seconds: 8)),
          plRaw: 6000.0, // Spike kick recorded today
          mlMagnitude: 9.81,
        ),
      ];

      final summary = service.calculateSummary(readings);

      // 1 kick detected today, no fabricated mock additions
      expect(summary.todayKicks, equals(1));
      expect(summary.weekKicks, equals(1));
      expect(summary.monthKicks, equals(1));
      expect(summary.dailyCounts7Days.length, equals(7));
      expect(summary.dailyCounts7Days.last, equals(1));
      expect(summary.dayLabels7Days.length, equals(7));
      expect(summary.dayLabels7Days.last, equals('Today'));
      expect(summary.recentKicks.length, equals(1));
      expect(summary.hasActivityInPast7Days, isTrue);
    });

    test('honestly reflects 0 kicks today and 0 this week when readings are 21 days old', () {
      final now = DateTime.now();
      final twentyOneDaysAgo = now.subtract(const Duration(days: 21));
      final readings = [
        SensorReading(
          entryId: 1,
          timestamp: twentyOneDaysAgo,
          plRaw: 1200.0,
          mlMagnitude: 9.80,
        ),
        SensorReading(
          entryId: 2,
          timestamp: twentyOneDaysAgo.add(const Duration(seconds: 2)),
          plRaw: 6000.0, // Spike kick that occurred 21 days ago
          mlMagnitude: 9.81,
        ),
      ];

      final summary = service.calculateSummary(readings);

      // Device was inactive today and this week -> strictly 0 kicks
      expect(summary.todayKicks, equals(0));
      expect(summary.weekKicks, equals(0));
      // Still within the 30-day month window (21 days <= 30)
      expect(summary.monthKicks, equals(1));
      expect(summary.totalStreamKicks, equals(1));
      // All 7 days in the last week have 0 recorded kicks
      expect(summary.dailyCounts7Days.every((c) => c == 0), isTrue);
      expect(summary.hasActivityInPast7Days, isFalse);
    });
  });
}
