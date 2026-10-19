class SensorReading {
  const SensorReading({
    required this.entryId,
    required this.timestamp,
    this.plRaw,
    this.prRaw,
    this.mlMagnitude,
    this.mrMagnitude,
    this.mlX,
    this.mlY,
    this.mrX,
    this.mrY,
  });

  final int entryId;
  final DateTime timestamp;
  final double? plRaw;
  final double? prRaw;
  final double? mlMagnitude;
  final double? mrMagnitude;
  final double? mlX;
  final double? mlY;
  final double? mrX;
  final double? mrY;

  /// ADS1115 GAIN_ONE converts 16-bit signed ADC count to volts (±4.096 V / 32768)
  double? get plVoltage => plRaw == null ? null : plRaw! * 0.000125;
  double? get prVoltage => prRaw == null ? null : prRaw! * 0.000125;

  factory SensorReading.fromThingSpeak(Map<String, dynamic> json) {
    double? number(String key) {
      final value = json[key];
      if (value == null || value.toString().trim().isEmpty) return null;
      return double.tryParse(value.toString());
    }

    return SensorReading(
      entryId: int.tryParse('${json['entry_id'] ?? 0}') ?? 0,
      timestamp: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      plRaw: number('field1'),
      prRaw: number('field2'),
      mlMagnitude: number('field3'),
      mrMagnitude: number('field4'),
      mlX: number('field5'),
      mlY: number('field6'),
      mrX: number('field7'),
      mrY: number('field8'),
    );
  }
}
