import '../models/sensor_reading.dart';
import 'signal_processor.dart';

enum KickHistoryPeriod {
  day,
  week,
  month,
}

class KickHistorySummary {
  const KickHistorySummary({
    required this.todayKicks,
    required this.weekKicks,
    required this.monthKicks,
    required this.dailyCounts7Days,
    required this.dayLabels7Days,
    required this.recentKicks,
    required this.restingPercentage,
    required this.totalStreamKicks,
    this.lastRecordedTimestamp,
  });

  final int todayKicks;
  final int weekKicks;
  final int monthKicks;
  final List<int> dailyCounts7Days;
  final List<String> dayLabels7Days;
  final List<KickEvent> recentKicks;
  final double restingPercentage;
  final int totalStreamKicks;
  final DateTime? lastRecordedTimestamp;

  bool get hasActivityInPast7Days => dailyCounts7Days.any((count) => count > 0);
}

class KickHistoryService {
  KickHistoryService({this.processor = const SignalProcessor()});

  final SignalProcessor processor;

  /// Calculates kick counts per day, per week (7 days), and per month (30 days)
  /// by running readings through the dual-sensor gating processor and grouping
  /// validated kicks by their actual historical timestamps.
  ///
  /// No fabricated baselines are added: if the device was inactive/offline,
  /// counts will truthfully reflect 0 for that period.
  KickHistorySummary calculateSummary(
    List<SensorReading> readings, {
    double piezoThreshold = 120.0,
    double maternalMotionThreshold = 0.35,
    bool enableFiltering = true,
    bool enablePiezoGate = true,
    bool enableMotionGate = true,
    DateTime? referenceTime,
  }) {
    final report = processor.analyzeReadings(
      readings,
      piezoThreshold: piezoThreshold,
      maternalMotionThreshold: maternalMotionThreshold,
      enableFiltering: enableFiltering,
      enablePiezoGate: enablePiezoGate,
      enableMotionGate: enableMotionGate,
    );

    final now = referenceTime ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = todayStart.subtract(const Duration(days: 29));

    final candidateKicks = report.candidateKicksList;

    // Kicks that occurred strictly on the current calendar day
    final todayKicks = candidateKicks.where((k) {
      return k.timestamp.year == now.year &&
          k.timestamp.month == now.month &&
          k.timestamp.day == now.day;
    }).length;

    // Kicks that occurred within the past 7 days (including today)
    final weekKicks = candidateKicks.where((k) {
      return !k.timestamp.isBefore(weekStart) &&
          !k.timestamp.isAfter(now.add(const Duration(minutes: 5)));
    }).length;

    // Kicks that occurred within the past 30 days
    final monthKicks = candidateKicks.where((k) {
      return !k.timestamp.isBefore(monthStart) &&
          !k.timestamp.isAfter(now.add(const Duration(minutes: 5)));
    }).length;

    // 7-day distribution (for each of past 6 days up to today)
    final daily7 = <int>[];
    final dayLabels = <String>[];
    for (var i = 6; i >= 0; i--) {
      final targetDate = todayStart.subtract(Duration(days: i));
      final count = candidateKicks.where((k) {
        return k.timestamp.year == targetDate.year &&
            k.timestamp.month == targetDate.month &&
            k.timestamp.day == targetDate.day;
      }).length;
      daily7.add(count);

      if (i == 0) {
        dayLabels.add('Today');
      } else {
        dayLabels.add(_shortDayName(targetDate.weekday));
      }
    }

    final lastTimestamp = readings.isNotEmpty ? readings.last.timestamp : null;

    return KickHistorySummary(
      todayKicks: todayKicks,
      weekKicks: weekKicks,
      monthKicks: monthKicks,
      dailyCounts7Days: daily7,
      dayLabels7Days: dayLabels,
      recentKicks: candidateKicks,
      restingPercentage: report.motherRestingPercentage,
      totalStreamKicks: report.candidateKickCount,
      lastRecordedTimestamp: lastTimestamp,
    );
  }

  static String _shortDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}
