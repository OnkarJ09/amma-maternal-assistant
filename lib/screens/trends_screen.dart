import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/monitoring_session.dart';
import '../models/sensor_reading.dart';
import '../services/calibration_service.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({
    super.key,
    required this.readings,
    required this.onRefresh,
    this.calibrationService,
  });

  final List<SensorReading> readings;
  final Future<void> Function() onRefresh;
  final CalibrationService? calibrationService;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int _sampleCount = 30;

  CalibrationService get _calibration =>
      widget.calibrationService ?? CalibrationService.instance;

  @override
  void initState() {
    super.initState();
    _calibration.addListener(_onCalibrationChanged);
  }

  @override
  void dispose() {
    _calibration.removeListener(_onCalibrationChanged);
    super.dispose();
  }

  void _onCalibrationChanged() {
    if (mounted) setState(() {});
  }

  List<SensorReading> get _filteredReadings {
    if (widget.readings.length <= _sampleCount) {
      return widget.readings;
    }
    return widget.readings.sublist(widget.readings.length - _sampleCount);
  }

  @override
  Widget build(BuildContext context) {
    final data = _filteredReadings;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: const Color(0xFF2F776B),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const Text(
            'Sensor Trends',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF183A36),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Longitudinal data from ThingSpeak channel 3465279.',
            style: TextStyle(fontSize: 13, color: Color(0xFF73827D)),
          ),
          const SizedBox(height: 16),
          _buildDepthSelector(data),
          const SizedBox(height: 16),
          if (data.isEmpty)
            _buildEmptyCard()
          else ...[
            _buildChartCard(
              title: 'Acceleration Magnitude',
              unit: 'm/s²',
              subtitle:
                  'Composite Euclidean magnitude √(X²+Y²+Z²). Includes ~9.8 m/s² gravity vector.',
              chart: _buildMagnitudeChart(data),
              legendLeft: 'Left MPU (ML)',
              legendRight: 'Right MPU (MR)',
              leftColor: const Color(0xFF2F776B),
              rightColor: const Color(0xFFC87565),
            ),
            const SizedBox(height: 16),
            _buildChartCard(
              title: 'Piezoelectric Transducers',
              unit: 'Raw ADC Counts',
              subtitle:
                  'High-precision 16-bit analog displacement sampled via ADS1115 (A1: PL, A0: PR). Red dashed line shows active kick threshold (${_calibration.piezoThreshold.toStringAsFixed(0)} ADC).',
              chart: _buildPiezoChart(data),
              legendLeft: 'Left Piezo (PL)',
              legendRight: 'Right Piezo (PR)',
              leftColor: const Color(0xFF2F776B),
              rightColor: const Color(0xFFC87565),
            ),
            const SizedBox(height: 16),
            _buildChartCard(
              title: 'Directional Acceleration Components',
              unit: 'm/s²',
              subtitle:
                  'X-axis (lateral) and Y-axis (longitudinal) motion trends from ML and MR sensors.',
              chart: _buildAxesChart(data),
              legendLeft: 'Left X (ML X)',
              legendRight: 'Right X (MR X)',
              leftColor: const Color(0xFF3B6899),
              rightColor: const Color(0xFF755191),
            ),
            const SizedBox(height: 16),
            _buildSummaryStatsCard(data),
          ],
        ],
      ),
    );
  }

  Widget _buildDepthSelector(List<SensorReading> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 15, label: Text('15')),
                ButtonSegment(value: 30, label: Text('30')),
                ButtonSegment(value: 60, label: Text('60')),
              ],
              selected: {_sampleCount},
              onSelectionChanged: (newSelection) {
                setState(() => _sampleCount = newSelection.first);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            OutlinedButton.icon(
              onPressed: data.isEmpty
                  ? null
                  : () {
                      final session = MonitoringSession(
                        id: 'TRENDS-${DateTime.now().millisecondsSinceEpoch}',
                        startTime: data.first.timestamp,
                        endTime: data.last.timestamp,
                        initialReadings: data,
                      );
                      final csv = session.toCsv();
                      Clipboard.setData(ClipboardData(text: csv));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Exported ${data.length} entries to CSV!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Export CSV'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2F776B),
                side: const BorderSide(color: Color(0xFF2F776B)),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.query_stats_rounded, size: 40, color: Color(0xFF73827D)),
              SizedBox(height: 10),
              Text(
                'No Historical Entries Found',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF183A36)),
              ),
              SizedBox(height: 4),
              Text(
                'Tap refresh or verify network access to load channel data.',
                style: TextStyle(fontSize: 12, color: Color(0xFF73827D)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String unit,
    required String subtitle,
    required Widget chart,
    required String legendLeft,
    required String legendRight,
    required Color leftColor,
    required Color rightColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF183A36),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F3EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2F776B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF73827D), height: 1.3),
            ),
            const SizedBox(height: 18),
            SizedBox(height: 190, child: chart),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: leftColor, label: legendLeft),
                const SizedBox(width: 24),
                _LegendDot(color: rightColor, label: legendRight),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMagnitudeChart(List<SensorReading> data) {
    final left = <FlSpot>[];
    final right = <FlSpot>[];

    for (var i = 0; i < data.length; i++) {
      if (data[i].mlMagnitude != null) left.add(FlSpot(i.toDouble(), data[i].mlMagnitude!));
      if (data[i].mrMagnitude != null) right.add(FlSpot(i.toDouble(), data[i].mrMagnitude!));
    }

    return _renderLineChart(
      spotsA: left,
      spotsB: right,
      colorA: const Color(0xFF2F776B),
      colorB: const Color(0xFFC87565),
      maxX: (data.length - 1).clamp(1, 100).toDouble(),
      valueFormatter: (v) => v.toStringAsFixed(1),
    );
  }

  Widget _buildPiezoChart(List<SensorReading> data) {
    final left = <FlSpot>[];
    final right = <FlSpot>[];

    for (var i = 0; i < data.length; i++) {
      if (data[i].plRaw != null) left.add(FlSpot(i.toDouble(), data[i].plRaw!));
      if (data[i].prRaw != null) right.add(FlSpot(i.toDouble(), data[i].prRaw!));
    }

    return _renderLineChart(
      spotsA: left,
      spotsB: right,
      colorA: const Color(0xFF2F776B),
      colorB: const Color(0xFFC87565),
      maxX: (data.length - 1).clamp(1, 100).toDouble(),
      thresholdY: _calibration.piezoThreshold,
      valueFormatter: (v) {
        if (v.abs() >= 1000) {
          return '${(v / 1000).toStringAsFixed(1)}k';
        }
        return v.toStringAsFixed(0);
      },
    );
  }

  Widget _buildAxesChart(List<SensorReading> data) {
    final mlXSpots = <FlSpot>[];
    final mrXSpots = <FlSpot>[];

    for (var i = 0; i < data.length; i++) {
      if (data[i].mlX != null) mlXSpots.add(FlSpot(i.toDouble(), data[i].mlX!));
      if (data[i].mrX != null) mrXSpots.add(FlSpot(i.toDouble(), data[i].mrX!));
    }

    return _renderLineChart(
      spotsA: mlXSpots,
      spotsB: mrXSpots,
      colorA: const Color(0xFF3B6899),
      colorB: const Color(0xFF755191),
      maxX: (data.length - 1).clamp(1, 100).toDouble(),
      valueFormatter: (v) => v.toStringAsFixed(1),
    );
  }

  Widget _renderLineChart({
    required List<FlSpot> spotsA,
    required List<FlSpot> spotsB,
    required Color colorA,
    required Color colorB,
    required double maxX,
    required String Function(double) valueFormatter,
    double? thresholdY,
  }) {
    if (spotsA.isEmpty && spotsB.isEmpty) {
      return const Center(
        child: Text('Awaiting valid data points', style: TextStyle(color: Color(0xFF73827D))),
      );
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: thresholdY != null
            ? ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: thresholdY,
                    color: const Color(0xFFC87565).withValues(alpha: 0.75),
                    strokeWidth: 1.5,
                    dashArray: [5, 5],
                  ),
                ],
              )
            : const ExtraLinesData(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, meta) => Text(
                valueFormatter(val),
                style: const TextStyle(color: Color(0xFF73827D), fontSize: 10),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(2),
                  TextStyle(
                    color: spot.bar.color ?? Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spotsA,
            isCurved: true,
            color: colorA,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spotsB,
            isCurved: true,
            color: colorB,
            barWidth: 2.2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatsCard(List<SensorReading> data) {
    double minMag = double.infinity;
    double maxMag = -double.infinity;
    double sumMag = 0;
    int countMag = 0;

    for (final r in data) {
      if (r.mlMagnitude != null) {
        minMag = min(minMag, r.mlMagnitude!);
        maxMag = max(maxMag, r.mlMagnitude!);
        sumMag += r.mlMagnitude!;
        countMag++;
      }
    }

    final avgMag = countMag > 0 ? (sumMag / countMag) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Observation Statistics (Window)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF183A36),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatMiniTile(
                    label: 'Min Mag',
                    value: minMag.isFinite ? '${minMag.toStringAsFixed(2)} m/s²' : '—',
                  ),
                ),
                Expanded(
                  child: _StatMiniTile(
                    label: 'Avg Mag',
                    value: avgMag != null ? '${avgMag.toStringAsFixed(2)} m/s²' : '—',
                  ),
                ),
                Expanded(
                  child: _StatMiniTile(
                    label: 'Max Mag',
                    value: maxMag.isFinite ? '${maxMag.toStringAsFixed(2)} m/s²' : '—',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMiniTile extends StatelessWidget {
  const _StatMiniTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF73827D)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF183A36),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF73827D), fontSize: 12),
        ),
      ],
    );
  }
}
