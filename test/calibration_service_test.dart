import 'package:amma_app/services/calibration_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalibrationService', () {
    late CalibrationService service;

    setUp(() {
      service = CalibrationService();
    });

    test('initializes with clinical factory defaults', () {
      expect(service.piezoThreshold, equals(1800.0));
      expect(service.motionThreshold, equals(0.35));
      expect(service.imuThreshold, equals(0.35));
      expect(service.enableFiltering, isTrue);
      expect(service.isCustomized, isFalse);
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

    test('resetToDefaults restores factory settings and notifies listeners', () {
      service.applyCalibration(
        piezoThreshold: 4500.0,
        motionThreshold: 0.80,
        enableFiltering: false,
      );
      expect(service.isCustomized, isTrue);

      int listenerFiredCount = 0;
      service.addListener(() => listenerFiredCount++);

      service.resetToDefaults();

      expect(service.piezoThreshold, equals(CalibrationService.defaultPiezoThreshold));
      expect(service.motionThreshold, equals(CalibrationService.defaultMotionThreshold));
      expect(service.imuThreshold, equals(CalibrationService.defaultMotionThreshold));
      expect(service.enableFiltering, equals(CalibrationService.defaultEnableFiltering));
      expect(service.isCustomized, isFalse);
      expect(listenerFiredCount, equals(1));
    });
  });
}
