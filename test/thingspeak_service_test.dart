import 'dart:convert';

import 'package:amma_app/services/thingspeak_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetches and sorts ThingSpeak feeds', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.thingspeak.com');
      expect(request.url.path, '/channels/3465279/feeds.json');
      return http.Response(jsonEncode({
        'feeds': [
          {'entry_id': 2, 'created_at': '2026-10-14T08:02:00Z', 'field1': '20'},
          {'entry_id': 1, 'created_at': '2026-10-14T08:01:00Z', 'field1': '10'},
        ],
      }), 200);
    });
    final service = ThingSpeakService(client: client);

    final readings = await service.fetchReadings();

    expect(readings.map((r) => r.entryId).toList(), [1, 2]);
    service.close();
  });

  test('throws a useful error for non-200 responses', () async {
    final service = ThingSpeakService(
      client: MockClient((_) async => http.Response('denied', 403)),
    );

    expect(
      service.fetchReadings(),
      throwsA(isA<ThingSpeakException>()),
    );
    service.close();
  });
}
