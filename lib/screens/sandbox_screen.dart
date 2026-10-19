import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sensor_reading.dart';
import '../services/signal_processor.dart';

class SandboxScreen extends StatefulWidget {
  const SandboxScreen({
    super.key,
    required this.readings,
    required this.onRefresh,
  });

  final List<SensorReading> readings;
  final Future<void> Function() onRefresh;

  @override
  State<SandboxScreen> createState() => _SandboxScreenState();
}

class _SandboxScreenState extends State<SandboxScreen> {
  final _processor = const SignalProcessor();

  double _piezoThreshold = 1800.0;
  double _motionThreshold = 0.35;
  bool _enableFiltering = true;

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
          _buildTuningControlsCard(teal, ink, muted),
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

  Widget _buildTuningControlsCard(Color teal, Color ink, Color muted) {
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
                const Expanded(
                  child: Text(
                    'Algorithm Parameters',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF183A36),
                    ),
                  ),
                ),
                Switch(
                  value: _enableFiltering,
                  activeTrackColor: teal,
                  onChanged: (val) => setState(() => _enableFiltering = val),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Piezo Spike Threshold (Bilateral max(PL, PR))',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${_piezoThreshold.toStringAsFixed(0)} ADC',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: teal,
                  ),
                ),
              ],
            ),
            Slider(
              value: _piezoThreshold,
              min: 500.0,
              max: 10000.0,
              divisions: 38,
              activeColor: teal,
              onChanged: (val) => setState(() => _piezoThreshold = val),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Maternal Dynamic Motion Gate (Δa deviation)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${_motionThreshold.toStringAsFixed(2)} m/s²',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: teal,
                  ),
                ),
              ],
            ),
            Slider(
              value: _motionThreshold,
              min: 0.05,
              max: 1.50,
              divisions: 29,
              activeColor: teal,
              onChanged: (val) => setState(() => _motionThreshold = val),
            ),
          ],
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
            unit: 'dual-validated',
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
            unit: 'mother active / refractory',
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
            const Text(
              'Red dashed line shows active piezo detection threshold across bilateral sensors.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF73827D)),
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
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: _piezoThreshold,
                              color: coral.withValues(alpha: 0.8),
                              strokeWidth: 1.5,
                              dashArray: [5, 5],
                            ),
                          ],
                        ),
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
