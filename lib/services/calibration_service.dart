import 'package:flutter/foundation.dart';

/// Centralized Calibration Service for AMMA signal processing algorithms.
///
/// Manages threshold configurations for dual-sensor kick gating:
/// - Bilateral Piezo Spike Threshold (max(PL, PR))
/// - Maternal Dynamic Motion Gate (deviation from rolling baseline)
/// - Digital high-pass baseline tracking filter toggle
///
/// Any screen can listen to updates via [ChangeNotifier] or invoke [applyCalibration]
/// to synchronize settings across Overview, Trends, and Sandbox.
class CalibrationService extends ChangeNotifier {
  CalibrationService({
    double piezoThreshold = defaultPiezoThreshold,
    double motionThreshold = defaultMotionThreshold,
    bool enableFiltering = defaultEnableFiltering,
  })  : _piezoThreshold = piezoThreshold,
        _motionThreshold = motionThreshold,
        _enableFiltering = enableFiltering;

  /// Global singleton instance
  static final CalibrationService instance = CalibrationService();

  static const double defaultPiezoThreshold = 1800.0;
  static const double defaultMotionThreshold = 0.35;
  static const bool defaultEnableFiltering = true;

  double _piezoThreshold;
  double _motionThreshold;
  bool _enableFiltering;

  /// Bilateral Piezo Spike Threshold (ADC counts, min(PL, PR) spike)
  double get piezoThreshold => _piezoThreshold;

  /// Maternal dynamic motion gate (m/s² Δa deviation from rolling baseline)
  double get motionThreshold => _motionThreshold;

  /// Alias for [motionThreshold] for IMU naming compatibility
  double get imuThreshold => _motionThreshold;

  /// Whether digital high-pass filter & baseline subtraction is enabled
  bool get enableFiltering => _enableFiltering;

  /// True if current settings differ from factory baseline defaults
  bool get isCustomized =>
      _piezoThreshold != defaultPiezoThreshold ||
      _motionThreshold != defaultMotionThreshold ||
      _enableFiltering != defaultEnableFiltering;

  /// Updates active threshold settings and notifies all listening UI components.
  void applyCalibration({
    required double piezoThreshold,
    double? motionThreshold,
    double? imuThreshold,
    bool? enableFiltering,
  }) {
    _piezoThreshold = piezoThreshold;
    _motionThreshold = motionThreshold ?? imuThreshold ?? _motionThreshold;
    if (enableFiltering != null) {
      _enableFiltering = enableFiltering;
    }
    notifyListeners();
  }

  /// Resets thresholds back to clinical factory defaults.
  void resetToDefaults() {
    _piezoThreshold = defaultPiezoThreshold;
    _motionThreshold = defaultMotionThreshold;
    _enableFiltering = defaultEnableFiltering;
    notifyListeners();
  }
}
