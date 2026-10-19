import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sensor_reading.dart';
import '../services/ble_service.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({
    super.key,
    required this.readings,
    required this.isLoading,
    required this.lastFetched,
    required this.onRefresh,
    this.currentIntervalSeconds = 20,
    this.currentStaleMinutes = 2,
    this.onOpenSyncSettings,
    this.bleService,
    this.isBleMode = false,
    this.onToggleMode,
    this.onOpenBleScanner,
  });

  final List<SensorReading> readings;
  final bool isLoading;
  final DateTime? lastFetched;
  final Future<void> Function() onRefresh;
  final int currentIntervalSeconds;
  final int currentStaleMinutes;
  final VoidCallback? onOpenSyncSettings;
  final BleTelemetryService? bleService;
  final bool isBleMode;
  final ValueChanged<bool>? onToggleMode;
  final VoidCallback? onOpenBleScanner;

  SensorReading? get _latest => readings.isEmpty ? null : readings.last;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF2F776B),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const Text(
            'Device & Architecture',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF183A36),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hardware mapping, I²C configuration, and data pipelines.',
            style: TextStyle(fontSize: 13, color: Color(0xFF73827D)),
          ),
          const SizedBox(height: 16),
          _buildModeSelector(),
          const SizedBox(height: 14),
          if (isBleMode) _buildBleConnectionCard(context) else _buildConnectionCard(),
          const SizedBox(height: 16),
          _buildSamplingArchitectureCard(),
          const SizedBox(height: 16),
          _buildHardwareMappingCard(),
          const SizedBox(height: 16),
          _buildSecurityNotice(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: false,
          label: Text('ThingSpeak Cloud', style: TextStyle(fontSize: 12.5)),
          icon: Icon(Icons.cloud_outlined, size: 18),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text('Direct BLE 5.0 (Offline)', style: TextStyle(fontSize: 12.5)),
          icon: Icon(Icons.bluetooth_rounded, size: 18),
        ),
      ],
      selected: {isBleMode},
      onSelectionChanged: (set) {
        if (set.isNotEmpty && onToggleMode != null) {
          onToggleMode!(set.first);
        }
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFE6F3EE);
          }
          return Colors.white;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF2F776B);
          }
          return const Color(0xFF73827D);
        }),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F3EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF2F776B)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ThingSpeak Cloud Channel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF183A36),
                        ),
                      ),
                      Text(
                        'Public REST Telemetry API',
                        style: TextStyle(fontSize: 12, color: Color(0xFF73827D)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow('Channel Name', 'amma-proto2'),
            _infoRow('Channel ID', '3465279'),
            _infoRow('Read Access', 'Public Read-Only (HTTPS)'),
            _infoRow(
              'Auto-Refresh Rate',
              currentIntervalSeconds == 0
                  ? 'Manual Only'
                  : 'Every $currentIntervalSeconds seconds',
            ),
            _infoRow(
              'Freshness Threshold',
              '$currentStaleMinutes minutes',
            ),
            _infoRow('Cached Entries', '${readings.length} records'),
            _infoRow(
              'Last Synchronized',
              lastFetched == null
                  ? 'Not synced'
                  : DateFormat('h:mm:ss a (d MMM)').format(lastFetched!),
            ),
            _infoRow(
              'Latest Cloud Entry ID',
              _latest == null ? 'None' : '#${_latest!.entryId}',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : onRefresh,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(isLoading ? 'Fetching...' : 'Refresh Now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2F776B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (onOpenSyncSettings != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onOpenSyncSettings,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Rates'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2F776B),
                      side: const BorderSide(color: Color(0xFF2F776B)),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBleConnectionCard(BuildContext context) {
    const teal = Color(0xFF2F776B);
    const ink = Color(0xFF183A36);
    const mint = Color(0xFFE6F3EE);
    const muted = Color(0xFF73827D);
    const coral = Color(0xFFC87565);

    final isStreaming = bleService?.status == BleConnectionStatus.streaming;
    final isConnected = bleService?.status == BleConnectionStatus.connected || isStreaming;
    final device = bleService?.connectedDevice;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isConnected ? mint : const Color(0xFFF2F5F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_disabled_rounded,
                    color: isConnected ? teal : muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Direct BLE 5.0 Link',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: ink,
                        ),
                      ),
                      Text(
                        isConnected ? 'Active 10 Hz Local Stream' : 'Offline Direct Pipeline',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isStreaming
                        ? (device?.isSimulated == true
                            ? const Color(0xFFFFF7ED)
                            : mint)
                        : isConnected
                            ? const Color(0xFFEAF1F8)
                            : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isStreaming
                        ? (device?.isSimulated == true ? '10 Hz (Simulated)' : '10 Hz Live')
                        : isConnected
                            ? 'Connected'
                            : 'Disconnected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isStreaming
                          ? (device?.isSimulated == true
                              ? const Color(0xFFB77927)
                              : teal)
                          : isConnected
                              ? const Color(0xFF3B6899)
                              : muted,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (device != null && device.isSimulated) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science_outlined, color: Color(0xFFB77927), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Demo Mode: Streaming synthetic 10 Hz telemetry for bench evaluation without physical ESP32 hardware.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8B5E34), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _infoRow('Target Device', device?.name ?? 'No device connected'),
            _infoRow(
              'Hardware ID',
              device == null
                  ? 'Scan required'
                  : (device.isSimulated ? 'Virtual Simulator' : device.id),
            ),
            _infoRow(
              'Signal Quality',
              device != null
                  ? (device.isSimulated ? 'Internal Loopback' : '${device.rssi} dBm (Optimal)')
                  : 'Unknown',
            ),
            _infoRow(
              'Stream Frequency',
              isStreaming ? '10 Hz (100 ms packet interval)' : 'Idle',
            ),
            _infoRow(
              'Current Throughput',
              isStreaming
                  ? '${bleService?.currentPacketRate.toStringAsFixed(1) ?? '0.0'} packets/s'
                  : '0.0 packets/s',
            ),
            _infoRow('Ingested Packets', '${bleService?.packetsReceived ?? 0} samples'),
            _infoRow('GATT Service UUID', '4F4D4D41-0001 (AMMA)'),
            _infoRow('Notify Char UUID', '4F4D4D41-0002 (Telemetry)'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isConnected
                        ? () => bleService?.disconnect()
                        : onOpenBleScanner,
                    icon: Icon(
                      isConnected
                          ? Icons.bluetooth_disabled_rounded
                          : Icons.bluetooth_searching_rounded,
                    ),
                    label: Text(isConnected ? 'Disconnect' : 'Scan for AMMA Band'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isConnected ? coral : teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

  Widget _buildSamplingArchitectureCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline_rounded, color: Color(0xFF2F776B)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sampling & Ingestion Architecture',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF183A36),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _ArchitectureStep(
              stepNumber: '1',
              title: 'Local High-Speed Sensing (10 Hz)',
              description:
                  'ESP32-S3 polls ADS1115 and dual MPU6050 every 100 ms locally. Updates OLED and serial monitor for immediate feedback.',
            ),
            SizedBox(height: 12),
            _ArchitectureStep(
              stepNumber: '2',
              title: 'Cloud Ingestion Rate (~20 Seconds)',
              description:
                  'Due to ThingSpeak rate limiting, summarized readings upload every ~20s over secure HTTPS. Cloud data represents longitudinal snapshots, not a 10 Hz continuous stream.',
            ),
            SizedBox(height: 12),
            _ArchitectureStep(
              stepNumber: '3',
              title: 'Companion App Ingestion',
              description:
                  'Android app performs read-only REST queries against ThingSpeak, caching up to 60 historical feeds with graceful error recovery.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareMappingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.memory_rounded, color: Color(0xFF2F776B)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hardware Sensor Mapping',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF183A36),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _sensorRow('Main Controller', 'ESP32-S3', 'Dual-core Xtensa, Wi-Fi 4, BLE 5.0'),
            const Divider(height: 18),
            _sensorRow('I²C Shared Bus', 'GPIO 8 (SDA), GPIO 9 (SCL)', '400 kHz Fast-Mode Clock'),
            const Divider(height: 18),
            _sensorRow('Analog ADC', 'ADS1115 (0x48)', '16-bit precision, ±4.096V range, 860 SPS'),
            const Divider(height: 18),
            _sensorRow('Left Piezo (PL)', 'ADS1115 Pin A1', 'Vibration/mechanical displacement sensor'),
            const Divider(height: 18),
            _sensorRow('Right Piezo (PR)', 'ADS1115 Pin A0', 'Vibration/mechanical displacement sensor'),
            const Divider(height: 18),
            _sensorRow('Left MPU (ML)', 'MPU6050 (0x69)', 'Left abdominal 3-axis accel (AD0 = VCC)'),
            const Divider(height: 18),
            _sensorRow('Right MPU (MR)', 'MPU6050 (0x68)', 'Right abdominal 3-axis accel (AD0 = GND)'),
            const Divider(height: 18),
            _sensorRow('Local Status OLED', 'SSD1306 (0x3C)', '128×64 monochrome display'),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F3EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4E7DF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF2F776B), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Security Architecture: This application operates under strict read-only access. Neither the ESP32 write API key nor the local Wi-Fi credentials are contained in or communicated to the Android client.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF2F776B),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF73827D)),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF183A36),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensorRow(String title, String address, String note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF183A36),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              address,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F776B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(note, style: const TextStyle(fontSize: 11, color: Color(0xFF73827D))),
      ],
    );
  }
}

class _ArchitectureStep extends StatelessWidget {
  const _ArchitectureStep({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final String stepNumber;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF2F776B),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF183A36),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF73827D),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
