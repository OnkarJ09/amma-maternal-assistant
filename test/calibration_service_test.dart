import 'package:amma_app/services/calibration_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalibrationService', () {
    late CalibrationService service;

    setUp(() {
      service = CalibrationService();
    });

    test('initializes with clinical factory defaults and dual-gating enabled', () {
      expect(service.piezoThreshold, equals(120.0));
      expect(service.motionThreshold, equals(0.35));
      expect(service.imuThreshold, equals(0.35));
      expect(service.enableFiltering, isTrue);
      expect(service.enablePiezoGate, isTrue);
      expect(service.enableMotionGate, isTrue);
      expect(service.isDualGated, isTrue);
      expect(service.isPiezoOnly, isFalse);
      expect(service.isMotionOnly, isFalse);
      expect(service.isCustomized, isFalse);
      expect(service.gatingModeLabel, equals('Dual-Sensor'));
    });

    test('applyCalibration updates thresholds and notifies listeners', () {
      int listenerFiredCount = 0;
      service.addListener(() => listenerFiredCount++);

      service.applyCalibration(
        piezoThreshold: 2400.0,
        motionThreshold: 0.60,
        enableFiltering: false,
      );

      expect(service.piezoThreshold, equals(2400.0));
      expect(service.motionThreshold, equals(0.60));
      expect(service.imuThreshold, equals(0.60));
      expect(service.enableFiltering, isFalse);
      expect(service.isCustomized, isTrue);
      expect(listenerFiredCount, equals(1));
    });

    test('supports disabling motion gate for Piezo-Only evaluation', () {
      service.applyCalibration(
        piezoThreshold: 2200.0,
        enablePiezoGate: true,
        enableMotionGate: false,
      );

      expect(service.isDualGated, isFalse);
      expect(service.isPiezoOnly, isTrue);
      expect(service.isMotionOnly, isFalse);
      expect(service.gatingModeLabel, equals('Piezo Only'));
      expect(service.isCustomized, isTrue);
    });

    test('supports disabling piezo gate for Motion-Only evaluation', () {
      service.applyCalibration(
        piezoThreshold: 1800.0,
        motionThreshold: 0.50,
        enablePiezoGate: false,
        enableMotionGate: true,
      );

      expect(service.isDualGated, isFalse);
      expect(service.isPiezoOnly, isFalse);
      expect(service.isMotionOnly, isTrue);
      expect(service.gatingModeLabel, equals('Motion Only'));
      expect(service.isCustomized, isTrue);
    });

    test('supports imuThreshold alias in applyCalibration', () {
      service.applyCalibration(
        piezoThreshold: 3100.0,
        imuThreshold: 0.45,
      );

      expect(service.piezoThreshold, equals(3100.0));
      expect(service.motionThreshold, equals(0.45));
      expect(service.imuThreshold, equals(0.45));
      expect(service.isCustomized, isTrue);
    });

    test('resetToDefaults restores factory settings and dual-gating', () {
      service.applyCalibration(
        piezoThreshold: 4500.0,
        motionThreshold: 0.80,
        enableFiltering: false,
        enablePiezoGate: true,
        enableMotionGate: false,
      );
      expect(service.isCustomized, isTrue);
      expect(service.isPiezoOnly, isTrue);

      int listenerFiredCount = 0;
      service.addListener(() => listenerFiredCount++);

      service.resetToDefaults();

      expect(service.piezoThreshold, equals(CalibrationService.defaultPiezoThreshold));
      expect(service.motionThreshold, equals(CalibrationService.defaultMotionThreshold));
      expect(service.imuThreshold, equals(CalibrationService.defaultMotionThreshold));
      expect(service.enableFiltering, equals(CalibrationService.defaultEnableFiltering));
      expect(service.enablePiezoGate, isTrue);
      expect(service.enableMotionGate, isTrue);
      expect(service.isDualGated, isTrue);
      expect(service.isCustomized, isFalse);
      expect(listenerFiredCount, equals(1));
    });
  });
}
