import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/monitoring_session.dart';
import '../models/sensor_reading.dart';
import '../services/calibration_service.dart';
import '../services/kick_history_service.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    required this.readings,
    required this.isLoading,
    required this.error,
    required this.lastFetched,
    required this.onRefresh,
    this.staleThresholdMinutes = 2,
    this.activeSession,
    this.onStartSession,
    this.onStopSession,
    this.onViewSessionSummary,
    this.onNavigateToSandbox,
    this.calibrationService,
  });

  final List<SensorReading> readings;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;
  final Future<void> Function() onRefresh;
  final int staleThresholdMinutes;
  final MonitoringSession? activeSession;
  final VoidCallback? onStartSession;
  final VoidCallback? onStopSession;
  final VoidCallback? onViewSessionSummary;
  final VoidCallback? onNavigateToSandbox;
  final CalibrationService? calibrationService;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final KickHistoryService _historyService = KickHistoryService();
  KickHistoryPeriod _selectedPeriod = KickHistoryPeriod.day;

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

  SensorReading? get _latest => widget.readings.isEmpty ? null : widget.readings.last;

  bool get _isStale {
    final reading = _latest;
    if (reading == null) return true;
    return DateTime.now().difference(reading.timestamp) >
        Duration(minutes: widget.staleThresholdMinutes);
  }

  String _formatStaleDuration(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inSeconds}s ago';
    }
  }

  String _formatVal(double? val, {int decimals = 2}) {
    if (val == null) return '—';
    return val.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reading = _latest;
    final summary = _historyService.calculateSummary(
      widget.readings,
      piezoThreshold: _calibration.piezoThreshold,
      maternalMotionThreshold: _calibration.motionThreshold,
      enableFiltering: _calibration.enableFiltering,
      enablePiezoGate: _calibration.enablePiezoGate,
      enableMotionGate: _calibration.enableMotionGate,
    );

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: const Color(0xFF2F776B),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          _buildHeroHeader(theme),
          const SizedBox(height: 16),
          _buildConnectionBanner(context),
          const SizedBox(height: 12),
          _buildSessionControlCard(context),
          if (widget.error != null) ...[
            const SizedBox(height: 12),
            _buildErrorNotice(context),
          ],
          const SizedBox(height: 16),
          _buildKickActivityCard(summary),
          const SizedBox(height: 20),
          _buildSectionTitle('Live Sensor Readings', 'Spatial arrangement across abdomen'),
          const SizedBox(height: 12),
          _buildMetricsGrid(reading),
          const SizedBox(height: 18),
          _buildDirectionalCard(reading),
          const SizedBox(height: 18),
          _buildMiniTrendCard(),
          const SizedBox(height: 22),
          _buildSafetyNotice(),
          const SizedBox(height: 14),
          Center(
            child: Text(
              widget.lastFetched == null
                  ? 'Connecting to ThingSpeak...'
                  : 'Sync checked at ${DateFormat('h:mm:ss a').format(widget.lastFetched!)}',
              style: const TextStyle(
                color: Color(0xFF73827D),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKickActivityCard(KickHistorySummary summary) {
    const teal = Color(0xFF2F776B);
    const ink = Color(0xFF183A36);
    const muted = Color(0xFF73827D);
    const mint = Color(0xFFE6F3EE);
    const coral = Color(0xFFC87565);

    int activeCount;
    String periodSubtitle;
    String clinicalBenchmark;
    bool isTargetMet;
    Color indicatorBg;
    Color indicatorColor;
    IconData indicatorIcon;

    final lastTime = summary.lastRecordedTimestamp;
    final int daysSinceLast = lastTime != null
        ? DateTime.now().difference(lastTime).inDays
        : 999;
    final isDeviceOffline = daysSinceLast > 1;

    switch (_selectedPeriod) {
      case KickHistoryPeriod.day:
        activeCount = summary.todayKicks;
        if (activeCount == 0 && isDeviceOffline) {
          periodSubtitle = summary.totalStreamKicks > 0
              ? 'No kicks today (${summary.totalStreamKicks} in stream)'
              : 'No kicks recorded today (Device offline)';
          clinicalBenchmark = summary.totalStreamKicks > 0
              ? 'Wearable inactive today (last logged session had ${summary.totalStreamKicks} kicks under ${_calibration.piezoThreshold.toStringAsFixed(0)} ADC threshold). Switch to Past Week tab to view.'
              : 'Wearable inactive for past ${daysSinceLast}d. Reconnect belt to record today\'s session.';
          isTargetMet = false;
          indicatorBg = const Color(0xFFFFF3E0);
          indicatorColor = const Color(0xFFB77927);
          indicatorIcon = summary.totalStreamKicks > 0
              ? Icons.history_rounded
              : Icons.sensors_off_rounded;
        } else {
          periodSubtitle = 'kicks recorded today';
          isTargetMet = activeCount >= 10;
          clinicalBenchmark = isTargetMet
              ? 'Meets Sadovsky count-to-ten standard (≥ 10 kicks / 2h session)'
              : 'Fewer than 10 kicks today. Continue counting in resting position.';
          indicatorBg = isTargetMet ? mint : const Color(0xFFFFF4E5);
          indicatorColor = isTargetMet ? teal : const Color(0xFFE67E22);
          indicatorIcon = isTargetMet ? Icons.check_circle_rounded : Icons.info_outline_rounded;
        }
        break;
      case KickHistoryPeriod.week:
        activeCount = summary.weekKicks;
        if (activeCount == 0 && isDeviceOffline) {
          periodSubtitle = '0 kicks over past 7 days (Offline)';
          clinicalBenchmark =
              'No wearable sessions logged in the last 7 days. Belt was last active ${daysSinceLast}d ago.';
          isTargetMet = false;
          indicatorBg = const Color(0xFFFFF3E0);
          indicatorColor = const Color(0xFFB77927);
          indicatorIcon = Icons.history_rounded;
        } else {
          periodSubtitle = 'kicks over past 7 days';
          isTargetMet = summary.weekKicks >= 60;
          final avg = (summary.weekKicks / 7).toStringAsFixed(1);
          clinicalBenchmark = 'Weekly daily average: $avg kicks/day • Steady maternal pattern';
          indicatorBg = isTargetMet ? mint : const Color(0xFFFFF4E5);
          indicatorColor = isTargetMet ? teal : const Color(0xFFE67E22);
          indicatorIcon = isTargetMet ? Icons.check_circle_rounded : Icons.info_outline_rounded;
        }
        break;
      case KickHistoryPeriod.month:
        activeCount = summary.monthKicks;
        periodSubtitle = 'kicks over past 30 days';
        isTargetMet = summary.monthKicks >= 20;
        final avg = (summary.monthKicks / 30).toStringAsFixed(1);
        clinicalBenchmark = activeCount > 0
            ? '30-day cumulative count: $activeCount kicks ($avg/day) • Logged ${daysSinceLast}d ago'
            : 'No kicks recorded within the last 30 days.';
        indicatorBg = isTargetMet ? mint : const Color(0xFFF0F4F2);
        indicatorColor = isTargetMet ? teal : muted;
        indicatorIcon = isTargetMet ? Icons.check_circle_rounded : Icons.history_rounded;
        break;
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE6EBE8), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.favorite_rounded, color: teal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fetal Movement Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _calibration.isDualGated
                            ? 'Dual-sensor gated (max(PL, PR) + IMU)'
                            : (_calibration.isPiezoOnly
                                ? 'Piezo-only gated (Motion gate bypassed)'
                                : 'Motion-only gated (Piezo threshold bypassed)'),
                        style: const TextStyle(fontSize: 11.5, color: muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _calibration.isDualGated
                        ? (_calibration.isCustomized
                            ? const Color(0xFFE0F2FE)
                            : const Color(0xFFE8F5E9))
                        : (_calibration.isPiezoOnly
                            ? const Color(0xFFFFF7ED)
                            : const Color(0xFFF3E8FF)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _calibration.isDualGated
                          ? (_calibration.isCustomized
                              ? const Color(0xFFBAE6FD)
                              : const Color(0xFFC8E6C9))
                          : (_calibration.isPiezoOnly
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFE9D5FF)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _calibration.isDualGated
                            ? (_calibration.isCustomized
                                ? Icons.tune_rounded
                                : Icons.verified_outlined)
                            : (_calibration.isPiezoOnly
                                ? Icons.graphic_eq_rounded
                                : Icons.directions_run_rounded),
                        size: 12,
                        color: _calibration.isDualGated
                            ? (_calibration.isCustomized
                                ? const Color(0xFF0369A1)
                                : const Color(0xFF2E7D32))
                            : (_calibration.isPiezoOnly
                                ? const Color(0xFFC2410C)
                                : const Color(0xFF7E22CE)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _calibration.isDualGated
                            ? (_calibration.isCustomized ? 'Tuned Dual Gate' : 'Calibrated')
                            : (_calibration.isPiezoOnly ? 'Piezo Only' : 'Motion Only'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _calibration.isDualGated
                              ? (_calibration.isCustomized
                                  ? const Color(0xFF0369A1)
                                  : const Color(0xFF2E7D32))
                              : (_calibration.isPiezoOnly
                                  ? const Color(0xFFC2410C)
                                  : const Color(0xFF7E22CE)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Segmented Period Switcher (Day / Week / Month)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F3),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _buildPeriodTab('Today', KickHistoryPeriod.day, summary.todayKicks),
                  _buildPeriodTab('Past Week', KickHistoryPeriod.week, summary.weekKicks),
                  _buildPeriodTab('Past Month', KickHistoryPeriod.month, summary.monthKicks),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Hero Metric Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$activeCount',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: ink,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        periodSubtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: teal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clinicalBenchmark,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: muted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: indicatorBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    indicatorIcon,
                    color: indicatorColor,
                    size: 20,
                  ),
                ),
              ],
            ),
            if (_selectedPeriod == KickHistoryPeriod.day &&
                activeCount == 0 &&
                summary.totalStreamKicks > 0) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _selectedPeriod = KickHistoryPeriod.week),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 15, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Latest session has ${summary.totalStreamKicks} kicks under ${_calibration.piezoThreshold.toStringAsFixed(0)} ADC threshold (${summary.weekKicks} past 7d). Tap to view Past Week.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFF16A34A)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),

            // 3-Column Period Comparison
            Row(
              children: [
                Expanded(
                  child: _buildPeriodMiniBox(
                    label: 'Today',
                    count: summary.todayKicks,
                    period: KickHistoryPeriod.day,
                    subtext: summary.todayKicks == 0 && isDeviceOffline
                        ? 'Offline (${daysSinceLast}d)'
                        : 'Daily target ≥10',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPeriodMiniBox(
                    label: '7 Days',
                    count: summary.weekKicks,
                    period: KickHistoryPeriod.week,
                    subtext: summary.weekKicks == 0
                        ? '0 this week'
                        : 'Avg ${(summary.weekKicks / 7).toStringAsFixed(1)}/day',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPeriodMiniBox(
                    label: '30 Days',
                    count: summary.monthKicks,
                    period: KickHistoryPeriod.month,
                    subtext: summary.monthKicks > 0
                        ? '${daysSinceLast}d ago'
                        : '0 this month',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 7-Day Activity Distribution Bar Chart
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '7-Day Activity Distribution',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ),
                if (!summary.hasActivityInPast7Days)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F5F4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Offline · 0 sessions this week',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Dashed red line indicates Cardiff/Sadovsky 10-kick reference mark.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (summary.dailyCounts7Days.reduce(max) * 1.25).clamp(16.0, 40.0),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < summary.dayLabels7Days.length) {
                            final isToday = idx == summary.dayLabels7Days.length - 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                summary.dayLabels7Days[idx],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                  color: isToday ? teal : muted,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 10.0,
                        color: coral.withValues(alpha: 0.6),
                        strokeWidth: 1.2,
                        dashArray: [4, 4],
                      ),
                    ],
                  ),
                  barGroups: List.generate(summary.dailyCounts7Days.length, (idx) {
                    final count = summary.dailyCounts7Days[idx];
                    final isToday = idx == summary.dailyCounts7Days.length - 1;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: count.toDouble(),
                          color: isToday ? teal : const Color(0xFF9FC2B4),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Calibration & Gating Status Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE6ECE9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, size: 14, color: teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _calibration.isDualGated
                          ? 'Gate: Dual-Sensor • Δa < ${_calibration.motionThreshold.toStringAsFixed(2)} m/s² • max(PL,PR) > ${_calibration.piezoThreshold.toStringAsFixed(0)} ADC'
                          : (_calibration.isPiezoOnly
                              ? 'Gate: Piezo Only • max(PL,PR) > ${_calibration.piezoThreshold.toStringAsFixed(0)} ADC (Motion rejection OFF)'
                              : 'Gate: Motion Only • Δa deviation > ${_calibration.motionThreshold.toStringAsFixed(2)} m/s² (Piezo threshold OFF)'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.onNavigateToSandbox != null)
                    InkWell(
                      onTap: widget.onNavigateToSandbox,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tune in Sandbox',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: teal,
                            ),
                          ),
                          Icon(Icons.arrow_forward_rounded, size: 12, color: teal),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(String label, KickHistoryPeriod period, int count) {
    final isSelected = _selectedPeriod == period;
    const teal = Color(0xFF2F776B);
    const ink = Color(0xFF183A36);
    const muted = Color(0xFF73827D);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedPeriod = period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? teal : muted,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? ink : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodMiniBox({
    required String label,
    required int count,
    required KickHistoryPeriod period,
    required String subtext,
  }) {
    final isSelected = _selectedPeriod == period;
    const teal = Color(0xFF2F776B);
    const ink = Color(0xFF183A36);
    const muted = Color(0xFF73827D);

    return InkWell(
      onTap: () => setState(() => _selectedPeriod = period),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEBF5F1) : const Color(0xFFF8FAF9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? teal : const Color(0xFFE5EDE8),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? teal : muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtext,
              style: const TextStyle(fontSize: 9.5, color: muted),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(ThemeData theme) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maternal Telemetry',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF183A36),
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Continuous objective sensing from the AMMA wearable belt.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF73827D),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionBanner(BuildContext context) {
    final hasData = _latest != null;
    final stale = _isStale;

    Color badgeColor;
    IconData badgeIcon;
    String statusTitle;
    String statusSubtitle;

    if (!hasData) {
      badgeColor = widget.isLoading ? const Color(0xFF2F776B) : const Color(0xFFC87565);
      badgeIcon = widget.isLoading ? Icons.sync_rounded : Icons.cloud_off_rounded;
      statusTitle = widget.isLoading ? 'Connecting to Wearable Channel' : 'No Readings Available';
      statusSubtitle = 'ThingSpeak Channel 3465279';
    } else if (stale) {
      badgeColor = const Color(0xFFB77927);
      badgeIcon = Icons.history_rounded;
      statusTitle = 'Wearable Inactive or Offline';
      statusSubtitle = 'Last logged ${_formatStaleDuration(_latest!.timestamp)} · Channel 3465279';
    } else {
      badgeColor = const Color(0xFF2F776B);
      badgeIcon = Icons.check_circle_rounded;
      statusTitle = 'Live Telemetry Active';
      statusSubtitle = 'Updated ${_formatStaleDuration(_latest!.timestamp)} · Channel 3465279';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F3EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4E7DF)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.isLoading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF2F776B),
                      ),
                    ),
                  )
                : Icon(badgeIcon, color: badgeColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF183A36),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF73827D),
                  ),
                ),
              ],
            ),
          ),
          if (stale && hasData)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: const Text(
                'STALE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB77927),
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionControlCard(BuildContext context) {
    const teal = Color(0xFF2F776B);
    const ink = Color(0xFF183A36);
    const muted = Color(0xFF73827D);
    final isRecording = widget.activeSession != null;

    return Card(
      color: isRecording ? const Color(0xFFEBF5F1) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isRecording ? teal : const Color(0xFFE9EEEA),
          width: isRecording ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isRecording ? teal : const Color(0xFFE6F3EE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRecording ? Icons.fiber_manual_record : Icons.play_arrow_rounded,
                    color: isRecording ? Colors.white : teal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRecording
                            ? 'Monitoring Session Active'
                            : 'Maternal Observation Session',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRecording
                            ? '${widget.activeSession!.sampleCount} feeds recorded · In progress'
                            : 'Record targeted 1–2 hr sessions with CSV export',
                        style: const TextStyle(fontSize: 11.5, color: muted),
                      ),
                    ],
                  ),
                ),
                if (!isRecording)
                  FilledButton.icon(
                    onPressed: widget.onStartSession,
                    icon: const Icon(Icons.fiber_manual_record, size: 14, color: Colors.white),
                    label: const Text('Start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: teal,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'View Summary & Export',
                        onPressed: widget.onViewSessionSummary,
                        icon: const Icon(Icons.assessment_outlined, color: teal),
                      ),
                      IconButton(
                        tooltip: 'Stop Session',
                        onPressed: widget.onStopSession,
                        icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFFC87565)),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorNotice(BuildContext context) {
    return Card(
      color: const Color(0xFFFDF2F0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF7D7D4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFC87565), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Network Sync Warning',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF183A36),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.error ?? 'Unable to refresh cloud readings.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73827D),
                      height: 1.35,
                    ),
                  ),
                  if (widget.readings.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Retaining previously loaded entries for continuity.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2F776B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF183A36),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF73827D),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(SensorReading? r) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                title: 'Left Piezo (PL)',
                subtitle: 'ADS1115 Pin A1',
                mainValue: _formatVal(r?.plRaw, decimals: 0),
                mainUnit: 'raw ADC',
                subValue: r?.plVoltage != null
                    ? '${_formatVal(r!.plVoltage, decimals: 3)} V'
                    : null,
                icon: Icons.graphic_eq_rounded,
                accentColor: const Color(0xFF2F776B),
                backgroundColor: const Color(0xFFE6F3EE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                title: 'Right Piezo (PR)',
                subtitle: 'ADS1115 Pin A0',
                mainValue: _formatVal(r?.prRaw, decimals: 0),
                mainUnit: 'raw ADC',
                subValue: r?.prVoltage != null
                    ? '${_formatVal(r!.prVoltage, decimals: 3)} V'
                    : null,
                icon: Icons.graphic_eq_rounded,
                accentColor: const Color(0xFFC87565),
                backgroundColor: const Color(0xFFFFEEEA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                title: 'Left Accel (ML)',
                subtitle: 'MPU6050 0x69',
                mainValue: _formatVal(r?.mlMagnitude),
                mainUnit: 'm/s² magnitude',
                subValue: 'Includes 1g gravity',
                icon: Icons.vibration_rounded,
                accentColor: const Color(0xFF3B6899),
                backgroundColor: const Color(0xFFEAF1F8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                title: 'Right Accel (MR)',
                subtitle: 'MPU6050 0x68',
                mainValue: _formatVal(r?.mrMagnitude),
                mainUnit: 'm/s² magnitude',
                subValue: 'Includes 1g gravity',
                icon: Icons.vibration_rounded,
                accentColor: const Color(0xFF755191),
                backgroundColor: const Color(0xFFF3EDF9),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectionalCard(SensorReading? r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              title: 'Multi-Axis Accelerations',
              subtitle: 'Planar abdominal motion components',
            ),
            const SizedBox(height: 14),
            _dataRow('Left X Acceleration (ML X)', '${_formatVal(r?.mlX)} m/s²'),
            _dataRow('Left Y Acceleration (ML Y)', '${_formatVal(r?.mlY)} m/s²'),
            const Divider(height: 18),
            _dataRow('Right X Acceleration (MR X)', '${_formatVal(r?.mrX)} m/s²'),
            _dataRow('Right Y Acceleration (MR Y)', '${_formatVal(r?.mrY)} m/s²'),
            const Divider(height: 18),
            _dataRow(
              'Observation Time',
              r == null ? '—' : DateFormat('d MMM yyyy, h:mm:ss a').format(r.timestamp),
            ),
            _dataRow('ThingSpeak Entry ID', r == null ? '—' : '#${r.entryId}'),
          ],
        ),
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF73827D),
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF183A36),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTrendCard() {
    final spotsLeft = <FlSpot>[];
    final spotsRight = <FlSpot>[];

    final recent = widget.readings.length > 20
        ? widget.readings.sublist(widget.readings.length - 20)
        : widget.readings;

    for (var i = 0; i < recent.length; i++) {
      if (recent[i].mlMagnitude != null) {
        spotsLeft.add(FlSpot(i.toDouble(), recent[i].mlMagnitude!));
      }
      if (recent[i].mrMagnitude != null) {
        spotsRight.add(FlSpot(i.toDouble(), recent[i].mrMagnitude!));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
              title: 'Recent Movement Overview',
              subtitle: 'Acceleration magnitude (m/s²) over last 20 cloud uploads',
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: spotsLeft.isEmpty && spotsRight.isEmpty
                  ? const Center(
                      child: Text(
                        'Awaiting cloud history...',
                        style: TextStyle(color: Color(0xFF73827D), fontSize: 13),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (recent.length - 1).clamp(1, 100).toDouble(),
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (v, m) => Text(
                                v.toStringAsFixed(0),
                                style: const TextStyle(
                                  color: Color(0xFF73827D),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineTouchData: const LineTouchData(enabled: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spotsLeft,
                            isCurved: true,
                            color: const Color(0xFF2F776B),
                            barWidth: 2.2,
                            dotData: const FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: spotsRight,
                            isCurved: true,
                            color: const Color(0xFFC87565),
                            barWidth: 2.2,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: Color(0xFF2F776B), label: 'Left (ML)'),
                SizedBox(width: 24),
                _LegendDot(color: Color(0xFFC87565), label: 'Right (MR)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyNotice() {
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
          Icon(Icons.shield_outlined, color: Color(0xFFB77927), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Research Prototype Notice: AMMA displays raw sensor telemetry for engineering validation. It does not calculate fetal kick counts or clinical scores. Always contact your doctor if you perceive reduced movement.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8B5E34),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.subtitle,
    required this.mainValue,
    required this.mainUnit,
    this.subValue,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });

  final String title;
  final String subtitle;
  final String mainValue;
  final String mainUnit;
  final String? subValue;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF73827D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF73827D),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                mainValue,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF183A36),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              mainUnit,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF73827D),
              ),
            ),
            if (subValue != null) ...[
              const SizedBox(height: 4),
              Text(
                subValue!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF183A36),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF73827D)),
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
