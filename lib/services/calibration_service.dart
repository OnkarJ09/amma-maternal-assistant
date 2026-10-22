import 'package:flutter/foundation.dart';

/// Centralized Calibration Service for AMMA signal processing algorithms.
///
/// Manages threshold configurations for dual-sensor kick gating:
/// - Bilateral Piezo Spike Threshold (max(PL, PR))
/// - Maternal Dynamic Motion Gate (deviation from rolling baseline)
/// - Digital high-pass baseline tracking filter toggle
/// - Individual gate activation toggles (Dual-sensor, Piezo-only, Motion-only)
///
/// Any screen can listen to updates via [ChangeNotifier] or invoke [applyCalibration]
/// to synchronize settings across Overview, Trends, and Sandbox.
class CalibrationService extends ChangeNotifier {
  CalibrationService({
    double piezoThreshold = defaultPiezoThreshold,
    double motionThreshold = defaultMotionThreshold,
    bool enableFiltering = defaultEnableFiltering,
    bool enablePiezoGate = true,
    bool enableMotionGate = true,
  })  : _piezoThreshold = piezoThreshold,
        _motionThreshold = motionThreshold,
        _enableFiltering = enableFiltering,
        _enablePiezoGate = enablePiezoGate,
        _enableMotionGate = enableMotionGate;

  /// Global singleton instance
  static final CalibrationService instance = CalibrationService();

  static const double defaultPiezoThreshold = 1800.0;
  static const double defaultMotionThreshold = 0.35;
  static const bool defaultEnableFiltering = true;

  double _piezoThreshold;
  double _motionThreshold;
  bool _enableFiltering;
  bool _enablePiezoGate;
  bool _enableMotionGate;

  /// Bilateral Piezo Spike Threshold (ADC counts, min(PL, PR) spike)
  double get piezoThreshold => _piezoThreshold;

  /// Maternal dynamic motion gate (m/s² Δa deviation from rolling baseline)
  double get motionThreshold => _motionThreshold;

  /// Alias for [motionThreshold] for IMU naming compatibility
  double get imuThreshold => _motionThreshold;

  /// Whether digital high-pass filter & baseline subtraction is enabled
  bool get enableFiltering => _enableFiltering;

  /// Whether the piezoelectric spike threshold gate is active
  bool get enablePiezoGate => _enablePiezoGate;

  /// Whether the maternal dynamic motion rejection gate is active
  bool get enableMotionGate => _enableMotionGate;

  /// True when both Piezo and Maternal Motion gates are active
  bool get isDualGated => _enablePiezoGate && _enableMotionGate;

  /// True when only the Piezo spike gate is active (motion gate disabled)
  bool get isPiezoOnly => _enablePiezoGate && !_enableMotionGate;

  /// True when only the IMU motion gate is active (piezo gate disabled)
  bool get isMotionOnly => !_enablePiezoGate && _enableMotionGate;

  /// Human-readable label for the active gating configuration
  String get gatingModeLabel {
    if (isDualGated) return 'Dual-Sensor';
    if (isPiezoOnly) return 'Piezo Only';
    return 'Motion Only';
  }

  /// True if current settings differ from factory baseline defaults
  bool get isCustomized =>
      _piezoThreshold != defaultPiezoThreshold ||
      _motionThreshold != defaultMotionThreshold ||
      _enableFiltering != defaultEnableFiltering ||
      !_enablePiezoGate ||
      !_enableMotionGate;

  /// Updates active threshold settings and notifies all listening UI components.
  void applyCalibration({
    required double piezoThreshold,
    double? motionThreshold,
    double? imuThreshold,
    bool? enableFiltering,
    bool? enablePiezoGate,
    bool? enableMotionGate,
  }) {
    _piezoThreshold = piezoThreshold;
    _motionThreshold = motionThreshold ?? imuThreshold ?? _motionThreshold;
    if (enableFiltering != null) {
      _enableFiltering = enableFiltering;
    }
    if (enablePiezoGate != null) {
      _enablePiezoGate = enablePiezoGate;
    }
    if (enableMotionGate != null) {
      _enableMotionGate = enableMotionGate;
    }
    notifyListeners();
  }

  /// Resets thresholds back to clinical factory defaults.
  void resetToDefaults() {
    _piezoThreshold = defaultPiezoThreshold;
    _motionThreshold = defaultMotionThreshold;
    _enableFiltering = defaultEnableFiltering;
    _enablePiezoGate = true;
    _enableMotionGate = true;
    notifyListeners();
  }
}
