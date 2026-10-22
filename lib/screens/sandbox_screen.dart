import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sensor_reading.dart';
import '../services/calibration_service.dart';
import '../services/signal_processor.dart';

class SandboxScreen extends StatefulWidget {
  const SandboxScreen({
    super.key,
    required this.readings,
    required this.onRefresh,
    this.calibrationService,
  });

  final List<SensorReading> readings;
  final Future<void> Function() onRefresh;
  final CalibrationService? calibrationService;

  @override
  State<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends State<SandboxScreen> {
  final _processor = const SignalProcessor();

  late double _piezoThreshold;
  late double _motionThreshold;
  late bool _enableFiltering;
  late bool _enablePiezoGate;
  late bool _enableMotionGate;

  CalibrationService get _calibration =>
      widget.calibrationService ?? CalibrationService.instance;

  bool get _isSyncedWithApp =>
      _piezoThreshold == _calibration.piezoThreshold &&
      _motionThreshold == _calibration.motionThreshold &&
      _enableFiltering == _calibration.enableFiltering &&
      _enablePiezoGate == _calibration.enablePiezoGate &&
      _enableMotionGate == _calibration.enableMotionGate;

  double get _sliderMin => _enableFiltering ? 50.0 : 1000.0;
  double get _sliderMax => _enableFiltering ? 8000.0 : 15000.0;
  int get _sliderDivisions => _enableFiltering ? 159 : 140;
  double get _clampedPiezoThreshold =>
      _piezoThreshold.clamp(_sliderMin, _sliderMax);

  @override
  void initState() {
    super.initState();
    _piezoThreshold = _calibration.piezoThreshold;
    _motionThreshold = _calibration.motionThreshold;
    _enableFiltering = _calibration.enableFiltering;
    _enablePiezoGate = _calibration.enablePiezoGate;
    _enableMotionGate = _calibration.enableMotionGate;
    _calibration.addListener(_onCalibrationChanged);
  }

  @override
  void dispose() {
    _calibration.removeListener(_onCalibrationChanged);
    super.dispose();
  }

  void _onCalibrationChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _setGatingMode({required bool piezo, required bool motion}) {
    if (!piezo && !motion) return;
    setState(() {
      _enablePiezoGate = piezo;
      _enableMotionGate = motion;
    });
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF2F776B);
    const ink = Color(0xFF183A36);
    const muted = Color(0xFF73827D);
    const coral = Color(0xFFC87565);

    final report = _processor.analyzeReadings(
      widget.readings,
      piezoThreshold: _piezoThreshold,
      maternalMotionThreshold: _motionThreshold,
      enableFiltering: _enableFiltering,
      enablePiezoGate: _enablePiezoGate,
      enableMotionGate: _enableMotionGate,
    );

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: teal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const Text(
            'Signal Analysis Sandbox',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Interactive evaluation of the dual-sensor kick gating algorithm.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 16),
          _buildTuningControlsCard(report, teal, ink, muted, coral),
          const SizedBox(height: 16),
          _buildMetricsOverview(report, teal, coral, ink, muted),
          const SizedBox(height: 16),
          _buildFilteredChartCard(report, teal, coral, ink, muted),
          const SizedBox(height: 16),
          _buildEventsTimelineCard(report, teal, coral, ink, muted),
          const SizedBox(height: 16),
          _buildDisclaimerNotice(),
        ],
      ),
    );
  }

  Widget _buildTuningControlsCard(
    SignalAnalysisReport report,
    Color teal,
    Color ink,
    Color muted,
    Color coral,
  ) {
    final isDual = _enablePiezoGate && _enableMotionGate;
    final isPiezoOnly = _enablePiezoGate && !_enableMotionGate;
    final isMotionOnly = !_enablePiezoGate && _enableMotionGate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF2F776B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Algorithm Parameters',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF183A36),
                        ),
                      ),
                      Text(
                        _enableFiltering
                            ? 'Digital High-Pass Filter ON (baseline subtraction active)'
                            : 'Raw ADC Counts Mode (no baseline filter)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF73827D)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enableFiltering,
                  activeTrackColor: teal,
                  onChanged: (val) {
                    setState(() {
                      _enableFiltering = val;
                      if (_enableFiltering && _piezoThreshold > 8000.0) {
                        _piezoThreshold = 1800.0;
                      } else if (!_enableFiltering && _piezoThreshold < 1000.0) {
                        _piezoThreshold = 5000.0;
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Gating Mode Selector
            const Text(
              'GATING MODE EVALUATION',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF73827D),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F3),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _buildModeTab(
                    label: 'Dual Gate',
                    isSelected: isDual,
                    teal: teal,
                    onTap: () => _setGatingMode(piezo: true, motion: true),
                  ),
                  _buildModeTab(
                    label: 'Piezo Only',
                    isSelected: isPiezoOnly,
                    teal: teal,
                    onTap: () => _setGatingMode(piezo: true, motion: false),
                  ),
                  _buildModeTab(
                    label: 'Motion Only',
                    isSelected: isMotionOnly,
                    teal: teal,
                    onTap: () => _setGatingMode(piezo: false, motion: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Piezo Spike Threshold Section with Toggle & Guidance
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _enablePiezoGate ? Colors.white : const Color(0xFFF9FAFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _enablePiezoGate
                      ? const Color(0xFFD4E3DD)
                      : const Color(0xFFE4E9E6),
                  width: _enablePiezoGate ? 1.2 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 16,
                        color: _enablePiezoGate ? teal : muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _enableFiltering
                              ? 'Piezo Spike Threshold (Δ ADC)'
                              : 'Piezo Spike Threshold (Raw ADC)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _enablePiezoGate ? ink : muted,
                          ),
                        ),
                      ),
                      Text(
                        _enablePiezoGate
                            ? '${_clampedPiezoThreshold.toStringAsFixed(0)} ADC'
                            : 'Disabled',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _enablePiezoGate ? teal : muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: _enablePiezoGate,
                        activeTrackColor: teal,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) {
                          if (!val && !_enableMotionGate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('At least one gating threshold must remain active.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          setState(() => _enablePiezoGate = val);
                        },
                      ),
                    ],
                  ),
                  if (_enablePiezoGate) ...[
                    const SizedBox(height: 4),
                    Slider(
                      value: _clampedPiezoThreshold,
                      min: _sliderMin,
                      max: _sliderMax,
                      divisions: _sliderDivisions,
                      activeColor: teal,
                      onChanged: (val) => setState(() => _piezoThreshold = val),
                    ),
                    // Quick Presets Row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _enableFiltering
                          ? [
                              _buildPresetChip('Bench: 120', 120.0, teal),
                              _buildPresetChip('Sensitive: 500', 500.0, teal),
                              _buildPresetChip('Clinical: 1800', 1800.0, teal),
                              _buildPresetChip('Firm: 3000', 3000.0, teal),
                              _buildPresetChip('Heavy: 5000', 5000.0, teal),
                            ]
                          : [
                              _buildPresetChip('Low: 3500', 3500.0, teal),
                              _buildPresetChip('PL Base: 4200', 4200.0, teal),
                              _buildPresetChip('Midpoint: 4700', 4700.0, teal),
                              _buildPresetChip('PR Base: 5200', 5200.0, teal),
                              _buildPresetChip('Spike: 7500', 7500.0, teal),
                            ],
                    ),
                    const SizedBox(height: 10),
                    // Live Signal Diagnostics Box
                    _buildPiezoDiagnosticBox(report, teal, ink, muted, coral),
                  ] else ...[
                    const SizedBox(height: 6),
                    const Text(
                      '⊘ Piezo threshold disabled — candidate events detected purely via dynamic IMU motion.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF8B5E34), fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Maternal Dynamic Motion Gate Section with Toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _enableMotionGate ? Colors.white : const Color(0xFFF9FAFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _enableMotionGate
                      ? const Color(0xFFD4E3DD)
                      : const Color(0xFFE4E9E6),
                  width: _enableMotionGate ? 1.2 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_run_rounded,
                        size: 16,
                        color: _enableMotionGate ? teal : muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Maternal Motion Gate',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _enableMotionGate ? ink : muted,
                          ),
                        ),
                      ),
                      Text(
                        _enableMotionGate
                            ? '${_motionThreshold.toStringAsFixed(2)} m/s²'
                            : 'Disabled',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _enableMotionGate ? teal : muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: _enableMotionGate,
                        activeTrackColor: teal,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) {
                          if (!val && !_enablePiezoGate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('At least one gating threshold must remain active.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          setState(() => _enableMotionGate = val);
                        },
                      ),
                    ],
                  ),
                  if (_enableMotionGate) ...[
                    const SizedBox(height: 4),
                    Slider(
                      value: _motionThreshold,
                      min: 0.05,
                      max: 1.50,
                      divisions: 29,
                      activeColor: teal,
                      onChanged: (val) => setState(() => _motionThreshold = val),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    const Text(
                      '⊘ Maternal motion rejection disabled — all piezo spikes validated without activity filtering.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF8B5E34), fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Sync Status Indicator Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _isSyncedWithApp
                    ? const Color(0xFFE6F3EE)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isSyncedWithApp
                      ? const Color(0xFFCBE3D9)
                      : const Color(0xFFFFE082),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSyncedWithApp
                        ? Icons.check_circle_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 15,
                    color: _isSyncedWithApp
                        ? teal
                        : const Color(0xFFB77927),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isSyncedWithApp
                          ? (_calibration.isDualGated
                              ? 'App Synced: Dual-Sensor gating active in Overview & Trends.'
                              : (_calibration.isPiezoOnly
                                  ? 'App Synced: Piezo-Only mode active (Motion gate bypassed).'
                                  : 'App Synced: Motion-Only mode active (Piezo threshold bypassed).'))
                          : 'Local Sandbox Preview: Tap Apply below to update Overview & Trends.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isSyncedWithApp
                            ? teal
                            : const Color(0xFF8B5E34),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Actions: Apply to App & Reset
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _calibration.applyCalibration(
                        piezoThreshold: _piezoThreshold,
                        motionThreshold: _motionThreshold,
                        enableFiltering: _enableFiltering,
                        enablePiezoGate: _enablePiezoGate,
                        enableMotionGate: _enableMotionGate,
                      );
                      setState(() {});

                      String feedbackMsg;
                      if (_enablePiezoGate && _enableMotionGate) {
                        feedbackMsg =
                            'Active calibration updated: Dual-Sensor Mode (${_piezoThreshold.toStringAsFixed(0)} ADC, ${_motionThreshold.toStringAsFixed(2)} m/s²). Applied to Overview & Trends!';
                      } else if (_enablePiezoGate) {
                        feedbackMsg =
                            'Active calibration updated: Piezo-Only Mode (${_piezoThreshold.toStringAsFixed(0)} ADC, Motion rejection OFF). Applied to Overview & Trends!';
                      } else {
                        feedbackMsg =
                            'Active calibration updated: Motion-Only Mode (${_motionThreshold.toStringAsFixed(2)} m/s², Piezo threshold OFF). Applied to Overview & Trends!';
                      }

                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(feedbackMsg),
                          backgroundColor: const Color(0xFF183A36),
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text(
                      'Apply Calibration to App',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ink,
                      side: const BorderSide(color: Color(0xFFD0D7D4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _calibration.resetToDefaults();
                      setState(() {
                        _piezoThreshold = _calibration.piezoThreshold;
                        _motionThreshold = _calibration.motionThreshold;
                        _enableFiltering = _calibration.enableFiltering;
                        _enablePiezoGate = _calibration.enablePiezoGate;
                        _enableMotionGate = _calibration.enableMotionGate;
                      });
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Calibration reset to factory defaults (Dual gate: ${_calibration.piezoThreshold.toStringAsFixed(0)} ADC, ${_calibration.motionThreshold.toStringAsFixed(2)} m/s²).',
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Reset to Defaults',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double val, Color teal) {
    final isSelected = (_piezoThreshold - val).abs() < 5;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _piezoThreshold = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? teal : const Color(0xFFF0F5F3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? teal : const Color(0xFFD4E3DD)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF2F776B),
          ),
        ),
      ),
    );
  }

  Widget _buildPiezoDiagnosticBox(
    SignalAnalysisReport report,
    Color teal,
    Color ink,
    Color muted,
    Color coral,
  ) {
    double avgPl = 0.0;
    double avgPr = 0.0;
    double maxSpike = 0.0;
    if (widget.readings.isNotEmpty) {
      final validPl = widget.readings.map((r) => r.plRaw).whereType<double>().toList();
      final validPr = widget.readings.map((r) => r.prRaw).whereType<double>().toList();
      if (validPl.isNotEmpty) avgPl = validPl.reduce((a, b) => a + b) / validPl.length;
      if (validPr.isNotEmpty) avgPr = validPr.reduce((a, b) => a + b) / validPr.length;
      if (report.points.isNotEmpty) {
        maxSpike = report.points.map((p) => p.effectiveSpike).reduce((a, b) => a > b ? a : b);
      }
    }

    final hasDetectedKicks = report.candidateKickCount > 0;
    final isThresholdAbovePeak = _piezoThreshold > maxSpike;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2EBE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RESTING BASELINE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF73827D),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'PL ~${avgPl.toStringAsFixed(0)} • PR ~${avgPr.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF183A36),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _enableFiltering ? 'PEAK TRANSIENT (Δ ADC)' : 'PEAK RAW ADC',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF73827D),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${maxSpike.toStringAsFixed(1)} ADC',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: hasDetectedKicks ? teal : coral,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: hasDetectedKicks ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasDetectedKicks ? const Color(0xFFC8E6C9) : const Color(0xFFFFECB3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasDetectedKicks ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 14,
                  color: hasDetectedKicks ? const Color(0xFF2E7D32) : const Color(0xFFB77927),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasDetectedKicks
                        ? 'Threshold (${_clampedPiezoThreshold.toStringAsFixed(0)} ADC) intersects transients: ${report.candidateKickCount} kicks detected!'
                        : 'Threshold (${_clampedPiezoThreshold.toStringAsFixed(0)} ADC) is above peak transient (${maxSpike.toStringAsFixed(0)} ADC). Lower slider to ≤ ${maxSpike.toStringAsFixed(0)} ADC to detect kicks.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: hasDetectedKicks ? const Color(0xFF2E7D32) : const Color(0xFF8D6E63),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_enableFiltering && isThresholdAbovePeak && maxSpike < 300) ...[
            const SizedBox(height: 6),
            const Text(
              '💡 Baseline Noise vs Transients: Hardware DC bias averages ~5000 ADC with baseline noise up to ~500 ADC (see docs/sensor_data). Digital filtering removes this DC bias so only dynamic kick transients are evaluated. In this motionless stream, transients are < 140 ADC (use 80–120 for bench testing; clinical threshold is 1800 ADC).',
              style: TextStyle(fontSize: 10, color: Color(0xFF73827D), height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool isSelected,
    required Color teal,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? teal : const Color(0xFF73827D),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsOverview(
    SignalAnalysisReport report,
    Color teal,
    Color coral,
    Color ink,
    Color muted,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Candidate Kicks',
            value: '${report.candidateKickCount}',
            unit: _enablePiezoGate && _enableMotionGate
                ? 'dual-validated'
                : (_enablePiezoGate ? 'piezo-only' : 'motion-only'),
            color: teal,
            bg: const Color(0xFFE6F3EE),
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Rejected Artifacts',
            value: '${report.rejectedArtifactCount}',
            unit: _enableMotionGate ? 'mother active / refractory' : 'refractory only (motion OFF)',
            color: coral,
            bg: const Color(0xFFFFEEEA),
            icon: Icons.cancel_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Resting State',
            value: '${report.motherRestingPercentage.toStringAsFixed(0)}%',
            unit: 'low maternal motion',
            color: const Color(0xFF3B6899),
            bg: const Color(0xFFEAF1F8),
            icon: Icons.bedtime_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredChartCard(
    SignalAnalysisReport report,
    Color teal,
    Color coral,
    Color ink,
    Color muted,
  ) {
    final spotsPl = <FlSpot>[];
    final spotsPr = <FlSpot>[];
    for (final p in report.points) {
      spotsPl.add(FlSpot(p.index.toDouble(), p.filteredPl));
      spotsPr.add(FlSpot(p.index.toDouble(), p.filteredPr));
    }

    const purple = Color(0xFF6B4E82);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtered Signal Waveforms & Threshold',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF183A36),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5F3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: teal, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('PL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: teal)),
                      const SizedBox(width: 8),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: purple, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('PR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: purple)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _enablePiezoGate
                  ? 'Red dashed line shows active piezo detection threshold across bilateral sensors.'
                  : 'Piezo detection threshold disabled (candidate kicks gated by IMU motion).',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF73827D)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 180,
              child: spotsPl.isEmpty
                  ? const Center(child: Text('No data points to display'))
                  : LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (spotsPl.length - 1).clamp(1, 100).toDouble(),
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 38,
                              getTitlesWidget: _formatLeftAxis,
                            ),
                          ),
                        ),
                        extraLinesData: _enablePiezoGate
                            ? ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: _clampedPiezoThreshold,
                                    color: coral.withValues(alpha: 0.8),
                                    strokeWidth: 1.5,
                                    dashArray: [5, 5],
                                  ),
                                ],
                              )
                            : const ExtraLinesData(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spotsPl,
                            isCurved: true,
                            color: teal,
                            barWidth: 2.0,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (spot, barData) {
                                final idx = spot.x.toInt();
                                if (idx >= 0 && idx < report.points.length) {
                                  final p = report.points[idx];
                                  return p.isCandidateKick && p.dominantChannel == PiezoChannel.left;
                                }
                                return false;
                              },
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 5,
                                  color: teal,
                                  strokeColor: Colors.white,
                                  strokeWidth: 2,
                                );
                              },
                            ),
                          ),
                          LineChartBarData(
                            spots: spotsPr,
                            isCurved: true,
                            color: purple,
                            barWidth: 2.0,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (spot, barData) {
                                final idx = spot.x.toInt();
                                if (idx >= 0 && idx < report.points.length) {
                                  final p = report.points[idx];
                                  return p.isCandidateKick && p.dominantChannel == PiezoChannel.right;
                                }
                                return false;
                              },
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 5,
                                  color: purple,
                                  strokeColor: Colors.white,
                                  strokeWidth: 2,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _formatLeftAxis(double val, TitleMeta meta) {
    if (val.abs() >= 1000) {
      final formatted = (val / 1000).toStringAsFixed(1);
      final clean = formatted.endsWith('.0')
          ? formatted.substring(0, formatted.length - 2)
          : formatted;
      return Text(
        '${clean}k',
        style: const TextStyle(fontSize: 10, color: Color(0xFF73827D)),
      );
    }
    return Text(
      val.toStringAsFixed(0),
      style: const TextStyle(fontSize: 10, color: Color(0xFF73827D)),
    );
  }

  Widget _buildEventsTimelineCard(
    SignalAnalysisReport report,
    Color teal,
    Color coral,
    Color ink,
    Color muted,
  ) {
    final events = report.points.where((p) => p.isCandidateKick || p.rejectionReason != null).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Event Classification Log',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF183A36),
                    ),
                  ),
                ),
                Text(
                  '${events.length} detected spikes',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF73827D)),
                ),
              ],
            ),
            const Divider(height: 20),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No transient spikes exceeded the current threshold.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF73827D)),
                  ),
                ),
              )
            else
              ...events.take(8).map((e) {
                final time = DateFormat('h:mm:ss a').format(e.timestamp);
                final sensorLabel = e.dominantChannel == PiezoChannel.left ? 'Left (PL)' : 'Right (PR)';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        e.isCandidateKick
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: e.isCandidateKick ? teal : coral,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF183A36),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.isCandidateKick
                              ? 'Validated Kick [$sensorLabel]: ${e.effectiveSpike.toStringAsFixed(0)} ADC'
                              : e.rejectionReason ?? 'Rejected transient',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: e.isCandidateKick ? teal : muted,
                            fontWeight: e.isCandidateKick ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: Color(0xFFB77927), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Research Algorithm Sandbox: Evaluates proposed digital filtering and dual-sensor gating logic on recorded telemetry. This is an engineering simulation for bench validation, not clinical diagnosis.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF8B5E34),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.bg,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color bg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF183A36),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF73827D),
              ),
            ),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF73827D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
