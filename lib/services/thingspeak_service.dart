import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sensor_reading.dart';

class ThingSpeakService {
  ThingSpeakService({
    http.Client? client,
    this.channelId = '3465279',
    this.readApiKey = const String.fromEnvironment('THINGSPEAK_READ_API_KEY'),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String channelId;
  final String readApiKey;

  Uri _feedsUri({int results = 30}) {
    return Uri.https(
      'api.thingspeak.com',
      '/channels/$channelId/feeds.json',
      {
        'results': '$results',
        if (readApiKey.isNotEmpty) 'api_key': readApiKey,
      },
    );
  }

  Future<List<SensorReading>> fetchReadings({int results = 30}) async {
    final response = await _client
        .get(_feedsUri(results: results))
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw ThingSpeakException(
        'ThingSpeak returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['feeds'] is! List) {
      throw const ThingSpeakException('Unexpected response from ThingSpeak.');
    }

    final feeds = decoded['feeds'] as List;
    final readings = feeds
        .whereType<Map<String, dynamic>>()
        .map(SensorReading.fromThingSpeak)
        .where((reading) => reading.timestamp.millisecondsSinceEpoch > 0)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return readings;
  }

  void close() => _client.close();
}

class ThingSpeakException implements Exception {
  const ThingSpeakException(this.message);
  final String message;

  @override
  String toString() => message;
}
