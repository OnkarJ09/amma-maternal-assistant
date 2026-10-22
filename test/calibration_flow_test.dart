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
      'Apply Calibration button and independent gating mode switching across Overview and Sandbox',
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

    // 1. Initial State on Overview: Dual-sensor calibrated
    expect(find.text('Calibrated'), findsOneWidget);
    expect(
      find.text('Gate: Dual-Sensor • Δa < 0.35 m/s² • max(PL,PR) > 1800 ADC'),
      findsOneWidget,
    );

    // 2. Navigate to Sandbox tab
    await tester.tap(find.text('Sandbox'));
    await tester.pumpAndSettle();

    expect(find.text('Signal Analysis Sandbox'), findsOneWidget);
    expect(find.text('Apply Calibration to App'), findsOneWidget);
    expect(find.text('Reset to Defaults'), findsOneWidget);
    expect(find.text('Dual Gate'), findsOneWidget);
    expect(find.text('Piezo Only'), findsOneWidget);
    expect(find.text('Motion Only'), findsOneWidget);

    // 3. Switch to 'Piezo Only' Mode (disables maternal motion gate)
    await tester.tap(find.text('Piezo Only'));
    await tester.pumpAndSettle();

    // Verify Piezo is enabled, and Motion gate shows Disabled
    expect(find.text('Disabled'), findsOneWidget);
    expect(
      find.text('⊘ Maternal motion rejection disabled — all piezo spikes validated without activity filtering.'),
      findsOneWidget,
    );

    // 4. Apply Piezo-Only calibration to App
    await tester.tap(find.text('Apply Calibration to App'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Active calibration updated: Piezo-Only Mode'), findsOneWidget);
    expect(calibrationService.isPiezoOnly, isTrue);
    expect(calibrationService.enableMotionGate, isFalse);

    // 5. Navigate to Overview and verify Piezo-Only status
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('Piezo Only'), findsOneWidget);
    expect(find.text('Piezo-only gated (Motion gate bypassed)'), findsOneWidget);
    expect(
      find.textContaining('Gate: Piezo Only • max(PL,PR) > 1800 ADC (Motion rejection OFF)'),
      findsOneWidget,
    );

    // 6. Navigate back to Sandbox and switch to 'Motion Only' Mode (disables piezo threshold)
    await tester.tap(find.text('Sandbox'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Motion Only'));
    await tester.pumpAndSettle();

    expect(
      find.text('⊘ Piezo threshold disabled — candidate events detected purely via dynamic IMU motion.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Apply Calibration to App'));
    await tester.pumpAndSettle();

    expect(calibrationService.isMotionOnly, isTrue);
    expect(calibrationService.enablePiezoGate, isFalse);

    // 7. Verify Overview in Motion-Only Mode
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('Motion Only'), findsOneWidget);
    expect(find.text('Motion-only gated (Piezo threshold bypassed)'), findsOneWidget);
    expect(
      find.textContaining('Gate: Motion Only • Δa deviation > 0.35 m/s² (Piezo threshold OFF)'),
      findsOneWidget,
    );

    // 8. Return to Sandbox and Reset to Factory Defaults
    await tester.tap(find.text('Sandbox'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset to Defaults'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Calibration reset to factory defaults'), findsOneWidget);
    expect(calibrationService.isDualGated, isTrue);
    expect(calibrationService.piezoThreshold, equals(1800.0));
    expect(calibrationService.motionThreshold, equals(0.35));

    // 9. Verify Overview returns to standard Dual-Sensor baseline
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('Calibrated'), findsOneWidget);
    expect(
      find.text('Gate: Dual-Sensor • Δa < 0.35 m/s² • max(PL,PR) > 1800 ADC'),
      findsOneWidget,
    );
  });
}
