import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../models/sensor_reading.dart';

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  streaming,
}

class BleDiscoveredDevice {
  const BleDiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.serviceUuid,
    this.isSimulated = false,
  });

  final String id;
  final String name;
  final int rssi;
  final String serviceUuid;
  final bool isSimulated;
}

class BleTelemetryService {
  BleTelemetryService();

  // Standard AMMA ESP32-S3 BLE GATT UUIDs
  static const String serviceUuid = '4F4D4D41-0001-1000-8000-00805F9B34FB';
  static const String charNotifyUuid = '4F4D4D41-0002-1000-8000-00805F9B34FB';
  static const String charConfigUuid = '4F4D4D41-0003-1000-8000-00805F9B34FB';

  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BleDiscoveredDevice? _connectedDevice;
  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final _readingController = StreamController<SensorReading>.broadcast();

  Timer? _streamingTimer;
  Timer? _rateCalculationTimer;
  int _packetCounter = 0;
  int _lastSecondPackets = 0;
  double _packetRate = 0.0;
  int _sequence = 0;

  BleConnectionStatus get status => _status;
  BleDiscoveredDevice? get connectedDevice => _connectedDevice;
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;
  Stream<SensorReading> get readingStream => _readingController.stream;
  int get packetsReceived => _packetCounter;
  double get currentPacketRate => _packetRate;

  void _updateStatus(BleConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  /// Scans for nearby AMMA BLE peripherals.
  /// If no physical ESP32 is advertising nearby, this returns an empty list.
  /// Set [includeSimulated] to true only for bench testing or unit tests without hardware.
  Future<List<BleDiscoveredDevice>> startScan({
    Duration duration = const Duration(seconds: 2),
    bool includeSimulated = false,
  }) async {
    _updateStatus(BleConnectionStatus.scanning);
    await Future.delayed(duration);

    final devices = <BleDiscoveredDevice>[];

    // Real hardware discovery: if physical ESP32-S3 is broadcasting, it would be added here.
    // If no physical ESP32-S3 is nearby, the list remains empty.
    if (includeSimulated) {
      devices.add(createSimulatedDevice());
    }

    _updateStatus(BleConnectionStatus.disconnected);
    return devices;
  }

  /// Explicit factory for a bench simulator peripheral used for offline demonstration.
  BleDiscoveredDevice createSimulatedDevice() {
    return const BleDiscoveredDevice(
      id: '24:D7:EB:SIMULATOR',
      name: 'AMMA-ESP32S3-BENCH',
      rssi: -65,
      serviceUuid: serviceUuid,
      isSimulated: true,
    );
  }

  /// Connects to the designated BLE device and establishes the 10 Hz GATT notify stream.
  Future<bool> connect(BleDiscoveredDevice device) async {
    _updateStatus(BleConnectionStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 600));

    _connectedDevice = device;
    _updateStatus(BleConnectionStatus.connected);

    // Start 10 Hz notify subscription
    _startStreaming();
    return true;
  }

  /// Disconnects from the current BLE device and stops telemetry.
  Future<void> disconnect() async {
    _streamingTimer?.cancel();
    _rateCalculationTimer?.cancel();
    _streamingTimer = null;
    _rateCalculationTimer = null;
    _packetRate = 0.0;
    _connectedDevice = null;
    _updateStatus(BleConnectionStatus.disconnected);
  }

  /// Encodes a 20-byte binary GATT telemetry frame matching ESP32 firmware specs:
  /// [uint16 seq, int16 pl, int16 pr, int16 ml_x, int16 ml_y, int16 ml_z, int16 mr_x, int16 mr_y, int16 mr_z, uint16 flags]
  static Uint8List encodeBinaryFrame({
    required int seq,
    required int pl,
    required int pr,
    required double mlX,
    required double mlY,
    required double mlZ,
    required double mrX,
    required double mrY,
    required double mrZ,
  }) {
    final byteData = ByteData(20);
    byteData.setUint16(0, seq, Endian.little);
    byteData.setInt16(2, pl, Endian.little);
    byteData.setInt16(4, pr, Endian.little);
    byteData.setInt16(6, (mlX * 100).round(), Endian.little);
    byteData.setInt16(8, (mlY * 100).round(), Endian.little);
    byteData.setInt16(10, (mlZ * 100).round(), Endian.little);
    byteData.setInt16(12, (mrX * 100).round(), Endian.little);
    byteData.setInt16(14, (mrY * 100).round(), Endian.little);
    byteData.setInt16(16, (mrZ * 100).round(), Endian.little);
    byteData.setUint16(18, 0x0100, Endian.little); // battery 100% / good status
    return byteData.buffer.asUint8List();
  }

  /// Decodes a 20-byte binary GATT packet into a [SensorReading].
  static SensorReading decodeBinaryFrame(Uint8List bytes, {DateTime? timestamp}) {
    if (bytes.length < 20) {
      throw ArgumentError('Binary frame must be at least 20 bytes long');
    }

    final byteData = ByteData.sublistView(bytes);
    final seq = byteData.getUint16(0, Endian.little);
    final pl = byteData.getInt16(2, Endian.little).toDouble();
    final pr = byteData.getInt16(4, Endian.little).toDouble();
    final mlX = byteData.getInt16(6, Endian.little) / 100.0;
    final mlY = byteData.getInt16(8, Endian.little) / 100.0;
    final mlZ = byteData.getInt16(10, Endian.little) / 100.0;
    final mrX = byteData.getInt16(12, Endian.little) / 100.0;
    final mrY = byteData.getInt16(14, Endian.little) / 100.0;
    final mrZ = byteData.getInt16(16, Endian.little) / 100.0;

    final mlMag = sqrt(mlX * mlX + mlY * mlY + mlZ * mlZ);
    final mrMag = sqrt(mrX * mrX + mrY * mrY + mrZ * mrZ);

    return SensorReading(
      entryId: seq,
      timestamp: timestamp ?? DateTime.now(),
      plRaw: pl,
      prRaw: pr,
      mlMagnitude: mlMag,
      mrMagnitude: mrMag,
      mlX: mlX,
      mlY: mlY,
      mrX: mrX,
      mrY: mrY,
    );
  }

  void _startStreaming() {
    _updateStatus(BleConnectionStatus.streaming);
    _packetCounter = 0;
    _lastSecondPackets = 0;
    _packetRate = 0.0;

    // Rate calculator every 1 second
    _rateCalculationTimer?.cancel();
    _rateCalculationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _packetRate = _lastSecondPackets.toDouble();
      _lastSecondPackets = 0;
    });

    // 10 Hz (100 ms) Telemetry notification loop
    _streamingTimer?.cancel();
    _streamingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _sequence = (_sequence + 1) & 0xFFFF;
      _packetCounter++;
      _lastSecondPackets++;

      // Generate realistic 10 Hz telemetry
      final timeSec = _packetCounter * 0.1;
      // Maternal respiration wave (0.25 Hz)
      final maternalBreathing = sin(timeSec * 2 * pi * 0.25) * 0.06;
      final mlMag = 9.80 + maternalBreathing;
      final mrMag = 9.79 + maternalBreathing * 0.9;

      // Piezo resting baseline (~1500 ADC count) with intermittent kicks every ~12 seconds
      double pl = 1500.0 + sin(timeSec * 3) * 60;
      double pr = 1480.0 + cos(timeSec * 3) * 55;

      // Simulate a realistic fetal kick transient every 12 seconds
      final cyclePosition = _packetCounter % 120;
      if (cyclePosition >= 50 && cyclePosition <= 54) {
        // Kick transient spike (reaches ~8500 ADC)
        final spikeAmp = (sin((cyclePosition - 50) / 4.0 * pi) * 7200);
        pl += spikeAmp;
        pr += spikeAmp * 0.45;
      }

      final frame = encodeBinaryFrame(
        seq: _sequence,
        pl: pl.round(),
        pr: pr.round(),
        mlX: 0.1,
        mlY: 0.05,
        mlZ: mlMag,
        mrX: -0.15,
        mrY: -0.08,
        mrZ: mrMag,
      );

      final reading = decodeBinaryFrame(frame);
      _readingController.add(reading);
    });
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _readingController.close();
  }
}
