# AMMA Android — Milestone 1

A Flutter starter app for the existing AMMA ESP32-S3 + ThingSpeak prototype. It reads ThingSpeak data only; it does not write to the channel or change ESP32 firmware.

## Included

- Premium maternal-wellness visual direction
- Dashboard cards for PL, PR, ML magnitude and MR magnitude
- Latest entry timestamp and entry ID
- Trends for acceleration magnitude, piezo raw ADC and X-axis comparison
- Device/cloud status and manual refresh
- Stale-data warning (latest reading older than two minutes)
- Network/API error handling while preserving previously loaded readings
- Unit tests for field mapping and ThingSpeak service behaviour
- Prototype/medical disclaimer

## Create the Flutter platform folders

From this extracted directory on Fedora:

```bash
flutter create --platforms=android .
flutter pub get
flutter analyze
flutter test
flutter run
```

If the project already exists, copy the included `lib/`, `test/`, `pubspec.yaml`, and `analysis_options.yaml` into it, reviewing any existing files before replacing them.

## ThingSpeak access

Default channel: `3465279`

If the channel is public, no read key is required. For a private channel, supply a **read-only** key at build/run time:

```bash
flutter run --dart-define=THINGSPEAK_READ_API_KEY=YOUR_READ_API_KEY
```

Do not use the ESP32 ThingSpeak **write** key in the app, and do not commit read credentials to Git. For a distributed production app, move private credentials behind a backend rather than shipping them in the APK.

## Data mapping

| ThingSpeak field | Meaning |
|---|---|
| field1 | PL raw ADC |
| field2 | PR raw ADC |
| field3 | ML acceleration magnitude (m/s²) |
| field4 | MR acceleration magnitude (m/s²) |
| field5 | ML X acceleration (m/s²) |
| field6 | ML Y acceleration (m/s²) |
| field7 | MR X acceleration (m/s²) |
| field8 | MR Y acceleration (m/s²) |

The firmware uploads roughly every 20 seconds. Sensor acquisition is 10 Hz locally, but the app only sees cloud-uploaded entries.

## Important scope note

This milestone does **not** implement fetal-kick detection, kick counting, medical alerts, maternal heart rate, SpO₂, or AI inference. Acceleration magnitude includes gravity and is not itself a fetal-kick measure. The app is a research prototype and must not be used to assess fetal wellbeing or delay clinical care.

## Google Antigravity handoff

Open this folder in Antigravity and ask it to:
1. inspect the project and current Flutter/Android SDK versions;
2. run `flutter pub get`, `flutter analyze`, and `flutter test`;
3. fix compile or lint errors without expanding scope;
4. run the app on an available emulator/device;
5. verify the public/private ThingSpeak access path and show a real-data dashboard;
6. build a debug APK and report the exact output path.

Do not ask it to replace the current ESP32 firmware or introduce Firebase, a separate backend, authentication, or an AI pipeline in this milestone.
