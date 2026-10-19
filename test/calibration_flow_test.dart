import 'dart:convert';

import 'package:amma_app/main.dart';
import 'package:amma_app/services/calibration_service.dart';
import 'package:amma_app/services/thingspeak_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
      'Apply Calibration to App button updates thresholds across Overview and Sandbox',
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
              'entry_id': 1,
              'created_at': '2026-10-19T08:00:00Z',
              'field1': '3200',
              'field2': '1500',
              'field3': '9.80',
              'field4': '9.80',
              'field5': '0.00',
              'field6': '0.00',
              'field7': '0.00',
              'field8': '0.00',
            }
          ],
        }),
        200,
      );
    });

    final service = ThingSpeakService(client: mockClient);
    final calibrationService = CalibrationService();

    await tester.pumpWidget(
      AmmaApp(
        service: service,
        calibrationService: calibrationService,
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initial State on Overview
    expect(find.text('Calibrated'), findsOneWidget);
    expect(
      find.text('Gate: Δa < 0.35 m/s² • max(PL,PR) > 1800 ADC'),
      findsOneWidget,
    );

    // 2. Navigate to Sandbox tab
    await tester.tap(find.text('Sandbox'));
    await tester.pumpAndSettle();

    expect(find.text('Signal Analysis Sandbox'), findsOneWidget);
    expect(find.text('Apply Calibration to App'), findsOneWidget);
    expect(find.text('Reset to Defaults'), findsOneWidget);
    expect(
      find.text('App Synced: Overview & Trends are using these thresholds.'),
      findsOneWidget,
    );

    // 3. Move Piezo Spike Threshold slider to higher value
    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(2));

    // Drag the first slider (Piezo Spike Threshold)
    await tester.drag(sliders.first, const Offset(150, 0));
    await tester.pumpAndSettle();

    // Verify unsaved preview indicator appears
    expect(
      find.text('Local Sandbox Preview: Tap Apply below to update Overview & Trends.'),
      findsOneWidget,
    );

    // 4. Tap 'Apply Calibration to App' button
    await tester.tap(find.text('Apply Calibration to App'));
    await tester.pumpAndSettle();

    // Verify confirmation SnackBar is displayed
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Active calibration updated: Piezo'), findsOneWidget);
    expect(find.textContaining('Applied to Overview & Trends!'), findsOneWidget);

    // Verify sync indicator updates to App Synced
    expect(
      find.text('App Synced: Overview & Trends are using these thresholds.'),
      findsOneWidget,
    );

    final updatedPiezo = calibrationService.piezoThreshold;
    expect(updatedPiezo, isNot(equals(1800.0)));

    // 5. Navigate back to Overview tab
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    // Verify Overview reflects Tuned Gate and new threshold in footer
    expect(find.text('Tuned Gate'), findsOneWidget);
    expect(
      find.text('Gate: Δa < 0.35 m/s² • max(PL,PR) > ${updatedPiezo.toStringAsFixed(0)} ADC'),
      findsOneWidget,
    );

    // 6. Navigate back to Sandbox and test 'Reset to Defaults'
    await tester.tap(find.text('Sandbox'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset to Defaults'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Calibration reset to factory defaults'), findsOneWidget);
    expect(calibrationService.piezoThreshold, equals(1800.0));
    expect(calibrationService.motionThreshold, equals(0.35));

    // 7. Verify Overview returns to standard calibrated baseline
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('Calibrated'), findsOneWidget);
    expect(
      find.text('Gate: Δa < 0.35 m/s² • max(PL,PR) > 1800 ADC'),
      findsOneWidget,
    );
  });
}
