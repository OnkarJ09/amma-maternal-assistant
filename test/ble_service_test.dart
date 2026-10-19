import 'package:amma_app/services/ble_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BleTelemetryService Protocol & Streaming', () {
    test('encodes and decodes 20-byte GATT binary frame accurately', () {
      final frame = BleTelemetryService.encodeBinaryFrame(
        seq: 42,
        pl: 6540,
        pr: 1820,
        mlX: 0.12,
        mlY: -0.25,
        mlZ: 9.81,
        mrX: -0.10,
        mrY: 0.05,
        mrZ: 9.79,
      );

      expect(frame.length, equals(20));

      final reading = BleTelemetryService.decodeBinaryFrame(frame);
      expect(reading.entryId, equals(42));
      expect(reading.plRaw, equals(6540.0));
      expect(reading.prRaw, equals(1820.0));
      expect(reading.mlX, closeTo(0.12, 0.01));
      expect(reading.mlY, closeTo(-0.25, 0.01));
      expect(reading.mlMagnitude, closeTo(9.81, 0.05));
    });

    test('scanning returns empty list when no physical hardware is broadcasting', () async {
      final service = BleTelemetryService();
      final devices = await service.startScan(duration: const Duration(milliseconds: 50));
      expect(devices, isEmpty);
      service.dispose();
    });

    test('simulation mode generates explicitly flagged bench peripheral', () async {
      final service = BleTelemetryService();
      final devices = await service.startScan(
        duration: const Duration(milliseconds: 50),
        includeSimulated: true,
      );
      expect(devices, isNotEmpty);
      expect(devices.first.isSimulated, isTrue);
      expect(devices.first.name, contains('AMMA-ESP32S3-BENCH'));
      expect(devices.first.serviceUuid, equals(BleTelemetryService.serviceUuid));
      service.dispose();
    });

    test('connecting starts 10 Hz streaming and disconnect stops it', () async {
      final service = BleTelemetryService();
      final target = service.createSimulatedDevice();

      final readings = <dynamic>[];
      final subscription = service.readingStream.listen((r) {
        readings.add(r);
      });

      final success = await service.connect(target);
      expect(success, isTrue);
      expect(service.status, equals(BleConnectionStatus.streaming));
      expect(service.connectedDevice?.name, equals(target.name));

      // Wait 350ms to accumulate 3-4 packets at 10 Hz
      await Future.delayed(const Duration(milliseconds: 350));
      expect(readings.length, greaterThanOrEqualTo(2));

      await service.disconnect();
      expect(service.status, equals(BleConnectionStatus.disconnected));
      expect(service.connectedDevice, isNull);

      final countAfterDisconnect = readings.length;
      await Future.delayed(const Duration(milliseconds: 200));
      expect(readings.length, equals(countAfterDisconnect)); // no more packets

      await subscription.cancel();
      service.dispose();
    });
  });
}
