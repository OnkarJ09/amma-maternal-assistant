import 'dart:convert';

import 'package:amma_app/main.dart';
import 'package:amma_app/services/thingspeak_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('AmmaApp renders header, navigation tabs, and switches views',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'channel': {'id': 3465279, 'name': 'amma-proto2'},
          'feeds': [
            {
              'entry_id': 323,
              'created_at': '2026-10-14T08:00:00Z',
              'field1': '8512',
              'field2': '1888',
              'field3': '10.68',
              'field4': '9.77',
              'field5': '0.62',
              'field6': '0.07',
              'field7': '-0.27',
              'field8': '-0.28',
            }
          ],
        }),
        200,
      );
    });

    final service = ThingSpeakService(client: mockClient);

    await tester.pumpWidget(AmmaApp(service: service));
    await tester.pumpAndSettle();

    // Verify AppBar branding
    expect(find.text('AMMA'), findsOneWidget);
    expect(find.text('Maternal Wellness Suite'), findsOneWidget);

    // Verify 5 Navigation Destinations
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Trends'), findsOneWidget);
    expect(find.text('Sandbox'), findsOneWidget);
    expect(find.text('Device'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    // Initial tab is Overview
    expect(find.text('Maternal Telemetry'), findsOneWidget);
    expect(find.text('Fetal Movement Activity'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Past Week'), findsOneWidget);
    expect(find.text('Past Month'), findsOneWidget);

    // Tap 'Past Week' tab
    await tester.tap(find.text('Past Week'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kicks over past 7 days'), findsOneWidget);

    // Tap 'Past Month' tab
    await tester.tap(find.text('Past Month'));
    await tester.pumpAndSettle();
    expect(find.textContaining('kicks over past 30 days'), findsOneWidget);

    // Scroll down to Live Sensor Readings
    await tester.scrollUntilVisible(find.text('Left Piezo (PL)'), 300);
    expect(find.text('Left Piezo (PL)'), findsOneWidget);
    expect(find.text('Right Piezo (PR)'), findsOneWidget);

    // Switch to Trends tab
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.text('Sensor Trends'), findsOneWidget);
    expect(find.text('Acceleration Magnitude'), findsOneWidget);

    // Switch to Sandbox tab
    await tester.tap(find.text('Sandbox'));
    await tester.pumpAndSettle();
    expect(find.text('Signal Analysis Sandbox'), findsOneWidget);
    expect(find.text('Algorithm Parameters'), findsOneWidget);
    expect(find.textContaining('Piezo Spike Threshold'), findsOneWidget);

    // Switch to Device tab
    await tester.tap(find.text('Device'));
    await tester.pumpAndSettle();
    expect(find.text('Device & Architecture'), findsOneWidget);
    expect(find.text('ThingSpeak Cloud Channel'), findsOneWidget);
    expect(find.text('Direct BLE 5.0 (Offline)'), findsOneWidget);

    // Toggle to Direct BLE mode on Device tab
    await tester.tap(find.text('Direct BLE 5.0 (Offline)'));
    await tester.pumpAndSettle();
    expect(find.text('Direct BLE 5.0 Link'), findsOneWidget);
    expect(find.text('Scan for AMMA Band'), findsOneWidget);

    // Toggle back to Cloud mode
    await tester.tap(find.text('ThingSpeak Cloud'));
    await tester.pumpAndSettle();
    expect(find.text('ThingSpeak Cloud Channel'), findsOneWidget);

    // Switch to About tab
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Settings & About'), findsOneWidget);
    expect(find.text('Important Clinical Disclaimer'), findsOneWidget);
    expect(
      find.text('Yeshwantrao Chavan College of Engineering (YCCE)'),
      findsOneWidget,
    );
  });
}
