import 'dart:math';

import 'package:intl/intl.dart';

import 'sensor_reading.dart';

class MonitoringSession {
  MonitoringSession({
    required this.id,
    required this.startTime,
    this.endTime,
    List<SensorReading>? initialReadings,
  }) : readings = initialReadings ?? [];

  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final List<SensorReading> readings;

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  int get sampleCount => readings.length;

  double? get peakPlRaw {
    double? peak;
    for (final r in readings) {
      if (r.plRaw != null) {
        peak = peak == null ? r.plRaw! : max(peak, r.plRaw!);
      }
    }
    return peak;
  }

  double? get peakPrRaw {
    double? peak;
    for (final r in readings) {
      if (r.prRaw != null) {
        peak = peak == null ? r.prRaw! : max(peak, r.prRaw!);
      }
    }
    return peak;
  }

  double? get peakMlMagnitude {
    double? peak;
    for (final r in readings) {
      if (r.mlMagnitude != null) {
        peak = peak == null ? r.mlMagnitude! : max(peak, r.mlMagnitude!);
      }
    }
    return peak;
  }

  double? get peakMrMagnitude {
    double? peak;
    for (final r in readings) {
      if (r.mrMagnitude != null) {
        peak = peak == null ? r.mrMagnitude! : max(peak, r.mrMagnitude!);
      }
    }
    return peak;
  }

  void addReading(SensorReading reading) {
    if (readings.isEmpty || readings.last.entryId != reading.entryId) {
      readings.add(reading);
    }
  }

  String toCsv() {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln(
      'Entry_ID,Timestamp_UTC,PL_Raw_ADC,PL_Volts,PR_Raw_ADC,PR_Volts,'
      'ML_Magnitude_ms2,MR_Magnitude_ms2,ML_X_ms2,ML_Y_ms2,MR_X_ms2,MR_Y_ms2',
    );

    final format = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final r in readings) {
      final plV = r.plVoltage != null ? r.plVoltage!.toStringAsFixed(4) : '';
      final prV = r.prVoltage != null ? r.prVoltage!.toStringAsFixed(4) : '';
      buffer.writeln(
        '${r.entryId},'
        '"${format.format(r.timestamp.toUtc())}",'
        '${r.plRaw ?? ""},'
        '$plV,'
        '${r.prRaw ?? ""},'
        '$prV,'
        '${r.mlMagnitude ?? ""},'
        '${r.mrMagnitude ?? ""},'
        '${r.mlX ?? ""},'
        '${r.mlY ?? ""},'
        '${r.mrX ?? ""},'
        '${r.mrY ?? ""}',
      );
    }
    return buffer.toString();
  }
}
