import 'package:flutter/material.dart';

import '../services/ble_service.dart';

class BleScannerSheet extends StatefulWidget {
  const BleScannerSheet({
    super.key,
    required this.bleService,
    required this.onConnected,
  });

  final BleTelemetryService bleService;
  final VoidCallback onConnected;

  @override
  State<BleScannerSheet> createState() => _BleScannerSheetState();
}

class _BleScannerSheetState extends State<BleScannerSheet> {
  bool _isScanning = false;
  String? _connectingDeviceId;
  List<BleDiscoveredDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    try {
      final results = await widget.bleService.startScan(
        duration: const Duration(seconds: 2),
      );
      if (!mounted) return;
      setState(() {
        _devices = results;
        _isScanning = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connect(BleDiscoveredDevice device) async {
    setState(() => _connectingDeviceId = device.id);
    final success = await widget.bleService.connect(device);
    if (!mounted) return;
    setState(() => _connectingDeviceId = null);

    if (success) {
      widget.onConnected();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.name}. 10 Hz local streaming active.'),
          backgroundColor: const Color(0xFF2F776B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF2F776B);
    const ink = Color(0xFF183A36);
    const mint = Color(0xFFE6F3EE);
    const muted = Color(0xFF73827D);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD9DEDC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bluetooth_searching_rounded, color: teal, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AMMA Band BLE Scanner',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: ink,
                      ),
                    ),
                    Text(
                      'Discover direct BLE 5.0 sensor peripherals',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Scan Again',
                onPressed: _isScanning ? null : _startScan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: teal),
                      )
                    : const Icon(Icons.refresh_rounded, color: ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: teal),
                    SizedBox(height: 12),
                    Text(
                      'Scanning 2.4 GHz BLE spectrum for AMMA peripherals...',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            )
          else if (_devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F5F4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bluetooth_searching_rounded,
                        size: 26,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No AMMA Band Found in Range',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '0 devices detected. Ensure your ESP32-S3 wearable belt is powered on, BLE advertising is active, and within Bluetooth range.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Scan Again'),
                      style: FilledButton.styleFrom(backgroundColor: teal),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        final simulated = widget.bleService.createSimulatedDevice();
                        _connect(simulated);
                      },
                      icon: const Icon(Icons.science_outlined, size: 16),
                      label: const Text('Test with Bench Simulator (Demo Mode)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: teal,
                        side: const BorderSide(color: Color(0xFFD4E7DF)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._devices.map((device) {
              final isConnecting = _connectingDeviceId == device.id;
              final isConnected = widget.bleService.connectedDevice?.id == device.id;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isConnected ? mint : const Color(0xFFF2F5F4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.bluetooth_connected_rounded,
                          color: isConnected ? teal : muted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    device.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: ink,
                                    ),
                                  ),
                                ),
                                if (device.isSimulated) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFFEDD5)),
                                    ),
                                    child: const Text(
                                      'Demo Simulator',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB77927),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              device.isSimulated
                                  ? 'Synthetic 10 Hz Telemetry'
                                  : '${device.id} • ${device.rssi} dBm (Good)',
                              style: const TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isConnected)
                        const Chip(
                          label: Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11,
                              color: teal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          backgroundColor: mint,
                          padding: EdgeInsets.zero,
                        )
                      else
                        FilledButton(
                          onPressed: isConnecting ? null : () => _connect(device),
                          style: FilledButton.styleFrom(
                            backgroundColor: teal,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: isConnecting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Connect'),
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'BLE 5.0 Direct Mode bypasses ThingSpeak cloud rate limits, streaming local telemetry at 10 samples per second directly to your phone for offline clinic observation.',
              style: TextStyle(fontSize: 11, color: muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
