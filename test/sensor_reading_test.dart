import 'package:flutter_test/flutter_test.dart';
import 'package:amma_app/models/sensor_reading.dart';

void main() {
  group('SensorReading.fromThingSpeak', () {
    test('maps the eight channel fields correctly', () {
      final reading = SensorReading.fromThingSpeak({
        'entry_id': 42,
        'created_at': '2026-10-14T08:30:00Z',
        'field1': '-384',
        'field2': '560',
        'field3': '9.70',
        'field4': '10.73',
        'field5': '-1.14',
        'field6': '-0.16',
        'field7': '-2.34',
        'field8': '0.14',
      });

      expect(reading.entryId, 42);
      expect(reading.plRaw, -384);
      expect(reading.prRaw, 560);
      expect(reading.mlMagnitude, 9.70);
      expect(reading.mrMagnitude, 10.73);
      expect(reading.mlX, -1.14);
      expect(reading.mlY, -0.16);
      expect(reading.mrX, -2.34);
      expect(reading.mrY, 0.14);

      // ADS1115 GAIN_ONE voltage conversion (0.125 mV per count)
      expect(reading.plVoltage, closeTo(-384 * 0.000125, 0.00001));
      expect(reading.prVoltage, closeTo(560 * 0.000125, 0.00001));
    });

    test('handles empty or missing fields without crashing', () {
      final reading = SensorReading.fromThingSpeak({
        'entry_id': '3',
        'created_at': '2026-10-14T08:30:00Z',
        'field1': '',
      });

      expect(reading.entryId, 3);
      expect(reading.plRaw, isNull);
      expect(reading.prRaw, isNull);
      expect(reading.plVoltage, isNull);
      expect(reading.prVoltage, isNull);
    });
  });
}
