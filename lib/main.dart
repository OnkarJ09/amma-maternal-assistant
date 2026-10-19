import 'dart:async';

import 'package:flutter/material.dart';

import 'models/monitoring_session.dart';
import 'models/sensor_reading.dart';
import 'screens/about_screen.dart';
import 'screens/device_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/sandbox_screen.dart';
import 'screens/trends_screen.dart';
import 'services/ble_service.dart';
import 'services/thingspeak_service.dart';
import 'widgets/ble_scanner_sheet.dart';
import 'widgets/session_summary_dialog.dart';
import 'widgets/sync_settings_sheet.dart';

void main() => runApp(const AmmaApp());

const _ink = Color(0xFF183A36);
const _teal = Color(0xFF2F776B);
const _mint = Color(0xFFE6F3EE);
const _paper = Color(0xFFF7F8F4);
const _muted = Color(0xFF73827D);

class AmmaApp extends StatelessWidget {
  const AmmaApp({super.key, this.service, this.bleService});

  final ThingSpeakService? service;
  final BleTelemetryService? bleService;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    return MaterialApp(
      title: 'AMMA | Maternal Wellness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: _paper,
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EEEA)),
          ),
        ),
      ),
      home: DashboardScreen(service: service, bleService: bleService),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.service, this.bleService});

  final ThingSpeakService? service;
  final BleTelemetryService? bleService;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ThingSpeakService _service;
  late final BleTelemetryService _bleService;
  List<SensorReading> _readings = [];
  bool _loading = true;
  String? _error;
  DateTime? _lastFetched;
  int _currentTab = 0;

  // Connection Pipeline Mode
  bool _isBleMode = false;
  StreamSubscription<SensorReading>? _bleReadingSub;
  StreamSubscription<BleConnectionStatus>? _bleStatusSub;

  // Auto-Sync and Freshness Settings
  int _autoRefreshInterval = 20; // 0 = Manual, 20s default
  int _staleThresholdMinutes = 2; // 2 minutes default
  int _countdown = 20;
  Timer? _countdownTimer;

  // Targeted Observation Session
  MonitoringSession? _activeSession;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ThingSpeakService();
    _bleService = widget.bleService ?? BleTelemetryService();

    // Listen to BLE status changes
    _bleStatusSub = _bleService.statusStream.listen((status) {
      if (mounted) setState(() {});
    });

    // Ingest 10 Hz BLE packets when in BLE mode
    _bleReadingSub = _bleService.readingStream.listen((reading) {
      if (!_isBleMode) return;
      if (!mounted) return;
      setState(() {
        _readings = [..._readings, reading];
        if (_readings.length > 100) {
          _readings = _readings.sublist(_readings.length - 100);
        }
        _lastFetched = reading.timestamp;
        if (_activeSession != null) {
          _activeSession!.addReading(reading);
        }
      });
    });

    _fetchData();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _bleReadingSub?.cancel();
    _bleStatusSub?.cancel();
    if (widget.bleService == null) {
      _bleService.dispose();
    }
    if (widget.service == null) {
      _service.close();
    }
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    if (_autoRefreshInterval == 0) return;

    _countdown = _autoRefreshInterval;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_autoRefreshInterval == 0) {
        timer.cancel();
        return;
      }

      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        // Trigger auto-fetch
        setState(() => _countdown = _autoRefreshInterval);
        _fetchData(silent: true);
      }
    });
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await _service.fetchReadings(results: 60);
      if (!mounted) return;
      setState(() {
        _readings = results;
        _lastFetched = DateTime.now();
        _error = null;
        _countdown = _autoRefreshInterval > 0 ? _autoRefreshInterval : 0;

        // If recording a session, accumulate new readings
        if (_activeSession != null) {
          for (final r in results) {
            _activeSession!.addReading(r);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  void _startSession() {
    final now = DateTime.now();
    final id = 'AMMA-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _activeSession = MonitoringSession(
        id: id,
        startTime: now,
        initialReadings: List.from(_readings),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Targeted monitoring session started.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _stopSession() {
    if (_activeSession == null) return;
    _activeSession!.endTime = DateTime.now();
    final finishedSession = _activeSession!;
    setState(() => _activeSession = null);

    showDialog(
      context: context,
      builder: (ctx) => SessionSummaryDialog(session: finishedSession),
    );
  }

  void _viewSessionSummary() {
    if (_activeSession == null) return;
    showDialog(
      context: context,
      builder: (ctx) => SessionSummaryDialog(session: _activeSession!),
    );
  }

  void _openBleScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BleScannerSheet(
        bleService: _bleService,
        onConnected: () {
          setState(() {
            _isBleMode = true;
          });
        },
      ),
    );
  }

  void _toggleDataMode(bool toBle) {
    setState(() => _isBleMode = toBle);
    if (!toBle) {
      _fetchData();
    }
  }

  void _openSyncSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SyncSettingsSheet(
        currentIntervalSeconds: _autoRefreshInterval,
        currentStaleMinutes: _staleThresholdMinutes,
        onIntervalChanged: (newSecs) {
          setState(() {
            _autoRefreshInterval = newSecs;
            _countdown = newSecs;
          });
          _startTimer();
        },
        onStaleMinutesChanged: (newMins) {
          setState(() => _staleThresholdMinutes = newMins);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _mint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.spa_rounded, color: _teal, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AMMA',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 1.2,
                      color: _ink,
                    ),
                  ),
                  Text(
                    'Maternal Wellness Suite',
                    style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Auto-sync / BLE indicator chip
          InkWell(
            onTap: _isBleMode ? _openBleScanner : _openSyncSettings,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _isBleMode
                    ? (_bleService.status == BleConnectionStatus.streaming
                        ? _mint
                        : const Color(0xFFF0F0F0))
                    : (_autoRefreshInterval > 0 ? _mint : const Color(0xFFF0F0F0)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isBleMode
                      ? (_bleService.status == BleConnectionStatus.streaming
                          ? const Color(0xFFD4E7DF)
                          : const Color(0xFFE0E0E0))
                      : (_autoRefreshInterval > 0
                          ? const Color(0xFFD4E7DF)
                          : const Color(0xFFE0E0E0)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isBleMode
                        ? (_bleService.status == BleConnectionStatus.streaming
                            ? Icons.bluetooth_connected_rounded
                            : Icons.bluetooth_rounded)
                        : (_autoRefreshInterval > 0
                            ? Icons.sync_rounded
                            : Icons.sync_disabled_rounded),
                    size: 14,
                    color: _isBleMode
                        ? (_bleService.status == BleConnectionStatus.streaming
                            ? _teal
                            : _muted)
                        : (_autoRefreshInterval > 0 ? _teal : _muted),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isBleMode
                        ? (_bleService.status == BleConnectionStatus.streaming
                            ? 'BLE 10Hz'
                            : 'BLE Off')
                        : (_autoRefreshInterval > 0 ? '${_countdown}s' : 'Manual'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _isBleMode
                          ? (_bleService.status == BleConnectionStatus.streaming
                              ? _teal
                              : _muted)
                          : (_autoRefreshInterval > 0 ? _teal : _muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _isBleMode ? 'BLE Stream Status' : 'Refresh Telemetry',
            onPressed: _loading
                ? null
                : () {
                    if (_isBleMode) {
                      if (_bleService.status == BleConnectionStatus.streaming) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Live BLE 5.0 streaming active: ${_bleService.packetsReceived} packets ingested at 10 Hz.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        _openBleScanner();
                      }
                    } else {
                      _fetchData();
                    }
                  },
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _teal),
                  )
                : Icon(
                    _isBleMode ? Icons.bluetooth_searching_rounded : Icons.refresh_rounded,
                    color: _ink,
                  ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab,
          children: [
            OverviewScreen(
              readings: _readings,
              isLoading: _loading,
              error: _error,
              lastFetched: _lastFetched,
              onRefresh: () => _fetchData(),
              staleThresholdMinutes: _staleThresholdMinutes,
              activeSession: _activeSession,
              onStartSession: _startSession,
              onStopSession: _stopSession,
              onViewSessionSummary: _viewSessionSummary,
              onNavigateToSandbox: () => setState(() => _currentTab = 2),
            ),
            TrendsScreen(
              readings: _readings,
              onRefresh: () => _fetchData(),
            ),
            SandboxScreen(
              readings: _readings,
              onRefresh: () => _fetchData(),
            ),
            DeviceScreen(
              readings: _readings,
              isLoading: _loading,
              lastFetched: _lastFetched,
              onRefresh: () => _fetchData(),
              currentIntervalSeconds: _autoRefreshInterval,
              currentStaleMinutes: _staleThresholdMinutes,
              onOpenSyncSettings: _openSyncSettings,
              bleService: _bleService,
              isBleMode: _isBleMode,
              onToggleMode: _toggleDataMode,
              onOpenBleScanner: _openBleScanner,
            ),
            const AboutScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (idx) => setState(() => _currentTab = idx),
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: _mint,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: _teal),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_rounded),
            selectedIcon: Icon(Icons.show_chart_rounded, color: _teal),
            label: 'Trends',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science_rounded, color: _teal),
            label: 'Sandbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_rounded),
            selectedIcon: Icon(Icons.sensors_rounded, color: _teal),
            label: 'Device',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline_rounded),
            selectedIcon: Icon(Icons.info_rounded, color: _teal),
            label: 'About',
          ),
        ],
      ),
    );
  }
}
