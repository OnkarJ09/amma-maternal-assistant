# AMMA (AI-Enabled Maternal Monitoring Assistant)
## Comprehensive Project Understanding & System Analysis

**Document Version:** 1.0  
**Date:** October 14, 2026  
**Author:** Lead Android Application Developer  
**Institution:** Yeshwantrao Chavan College of Engineering (YCCE), Department of Electronics Engineering (VLSI Design & Technology)  
**Project Guide:** Dr. Prachi P. Palsodkar  

---

## 1. Project Purpose, Target Users, and Product Vision

### 1.1 Project Purpose
In conventional obstetrics, fetal movement tracking ("kick counting") during the third trimester serves as an essential, non-invasive proxy for fetal wellbeing and central nervous system integrity. Decreased fetal movement (DFM) is a well-established clinical precursor to fetal distress, placental insufficiency, and potential stillbirth. 

However, existing manual maternal kick-counting methods suffer from significant clinical limitations:
- **Subjective Perception:** Maternal awareness varies drastically depending on maternal activity, sleep cycles, placental position (e.g., anterior placenta), amniotic fluid volume, and maternal habitus.
- **Episodic & Infrequent:** Typically performed only once or twice daily for 1–2 hours, leaving extensive unmonitored windows.
- **Delayed Intervention:** Expectant mothers often delay reporting reduced movement by 12–24 hours due to uncertainty or hesitation, frequently missing the critical 2–3 hour clinical intervention window.

**AMMA (AI-Enabled Maternal Monitoring Assistant / Maternal Wellness Suite)** is conceived as an affordable, continuous, non-invasive wearable solution that replaces episodic, subjective maternal perception with continuous, objective sensor telemetry and cloud-assisted trend monitoring.

### 1.2 Target Users
1. **Expectant Mothers (Third Trimester, Gestational Weeks 28–40):** Primary end-users seeking continuous reassurance, passive tracking during routine daytime activity and sleep, and timely notifications if physiological trends deviate from established norms.
2. **Obstetricians and Maternity Healthcare Teams:** Secondary clinical users who require verified, objective longitudinal trends of abdominal mechanical and vibrational activity rather than anecdotal maternal recall.
3. **Rural and Semi-Urban Healthcare Workers (ASHA/ANM Workers):** Facilitators in low-resource Indian public health settings where cardiotocography (CTG) and Doppler ultrasound are inaccessible or cost-prohibitive.

### 1.3 Product Vision
The long-term vision is a low-cost (< ₹2,000 INR bill-of-materials) ergonomic wearable abdominal belt paired with an edge-computing microcontroller, an intelligent companion mobile application, and clinical AI. The system establishes an individualized baseline for each pregnancy over a 72-hour period, applies circadian-aware filtering, suppresses maternal motion artifacts, and provides calibrated, progressive escalation alerts to avert adverse perinatal outcomes.

---

## 2. Current Hardware Architecture and Sensor Mapping

The verified working prototype (**AMMA Prototype 2 / IEEE Conference Prototype**) has stabilized on an **ESP32-S3** microcontroller board with dedicated peripheral sensor modules communicating over a high-speed I²C bus.

```
                           +------------------------+
                           |  ESP32-S3 (Main MCU)   |
                           |  Dual-Core Xtensa LX7  |
                           +-----------+------------+
                                       |
                     I²C Bus (SDA: GPIO 8, SCL: GPIO 9 @ 400 kHz)
         +-------------------+---------+--------------------+
         |                   |                              |
         v                   v                              v
+-----------------+ +-----------------+            +-----------------+
|  OLED Display   | | ADS1115 16-bit  |            |   Dual MPU6050  |
|  SSD1306 128x64 | | External ADC    |            |   6-DoF IMUs    |
|  Addr: 0x3C     | | Addr: 0x48      |            | (Accel + Gyro)  |
+-----------------+ +--------+--------+            +--------+--------+
                             |                              |
              +--------------+--------------+       +-------+-------+
              |                             |       |               |
              v                             v       v               v
       +--------------+             +--------------+  Left MPU        Right MPU
       | Left Piezo   |             | Right Piezo  |  (ML, 0x69)      (MR, 0x68)
       | (PL) on A1   |             | (PR) on A0   |  AD0 = VCC       AD0 = GND
       +--------------+             +--------------+
```

### 2.1 Component Specifications and Pinout

| Component | Model / Spec | Interface / Pins | Address / Channel | Functional Responsibility |
|---|---|---|---|---|
| **Microcontroller** | ESP32-S3 Dev Module | Dual Core, 2.4 GHz Wi-Fi 4, BLE 5.0 | N/A | 10 Hz local acquisition loop, OLED driver, HTTPS client |
| **I²C Controller** | ESP32-S3 Hardware I²C | GPIO 8 (SDA), GPIO 9 (SCL) | Bus Speed: 400 kHz | Shared sensor telemetry communication bus |
| **Analog-to-Digital Converter** | ADS1115 (16-bit precision) | I²C (SDA 8, SCL 9) | Address: `0x48` (ADDR -> GND) | Eliminates ESP32 internal ADC noise; ±4.096V range (GAIN_ONE), 860 SPS |
| **Left Piezo Sensor (PL)** | Piezoelectric transducer element | Analog output to ADS1115 A1 | Single-ended channel 1 | Captures transient localized acoustic/mechanical shockwaves from left abdomen |
| **Right Piezo Sensor (PR)** | Piezoelectric transducer element | Analog output to ADS1115 A0 | Single-ended channel 0 | Captures transient localized acoustic/mechanical shockwaves from right abdomen |
| **Left Inertial Sensor (ML)** | MPU6050 6-axis IMU | I²C (SDA 8, SCL 9) | Address: `0x69` (AD0 tied high to 3.3V) | Measures left abdominal 3-axis acceleration (±8g, 21 Hz DLPF) |
| **Right Inertial Sensor (MR)** | MPU6050 6-axis IMU | I²C (SDA 8, SCL 9) | Address: `0x68` (AD0 tied low to GND) | Measures right abdominal 3-axis acceleration (±8g, 21 Hz DLPF) |
| **Local Status Display** | SSD1306 0.96" OLED (128×64) | I²C (SDA 8, SCL 9) | Address: `0x3C` | Real-time standalone display of PL/PR raw ADC, ML/MR magnitude, Wi-Fi status |

---

## 3. Existing ESP32-S3 Firmware Capabilities

Based directly on the runtime firmware source code (`reading.txt`), the ESP32-S3 executes two decoupled timing loops:

### 3.1 Local High-Rate Sensing Loop (100 ms Interval = 10 Hz)
- **ADS1115 Acquisition:**
  - Reads channel A1: `plRaw` (int16 ADC counts). Computes `plVoltage = ads.computeVolts(plRaw)`.
  - Reads channel A0: `prRaw` (int16 ADC counts). Computes `prVoltage = ads.computeVolts(prRaw)`.
- **MPU6050 Acquisition:**
  - Queries `mpuLeft` (`0x69`): reads acceleration vector ($X_{ML}, Y_{ML}, Z_{ML}$) in $\text{m/s}^2$.
  - Queries `mpuRight` (`0x68`): reads acceleration vector ($X_{MR}, Y_{MR}, Z_{MR}$) in $\text{m/s}^2$.
  - Calculates orientation-independent Euclidean magnitude:
    $$\text{Magnitude}_{ML} = \sqrt{X_{ML}^2 + Y_{ML}^2 + Z_{ML}^2}$$
    $$\text{Magnitude}_{MR} = \sqrt{X_{MR}^2 + Y_{MR}^2 + Z_{MR}^2}$$
- **Local OLED Rendering:**
  - Clears buffer, renders header "AMMA SENSOR MONITOR", outputs `PL` and `PR` raw values, `ML MAG` and `MR MAG` to two decimal places, and network status ("WiFi: OK" / "WiFi: OFF").
- **Serial Console Telemetry:**
  - Streams structured diagnostic telemetry at 115,200 baud for debugging.

### 3.2 Cloud Transmission Loop (20,000 ms Interval = ~20 Seconds)
- Verifies Wi-Fi connectivity (`WiFi.status() == WL_CONNECTED`). If disconnected, automatically attempts reconnection with a 30-retry limit.
- Instantiates an insecure TLS client (`WiFiClientSecure client; client.setInsecure();`) to avoid onboard X.509 certificate expiry issues during prototype bench tests.
- Constructs an HTTP GET query to `https://api.thingspeak.com/update` with parameters:
  - `api_key=WRITE_API_KEY`
  - `field1=plRaw`
  - `field2=prRaw`
  - `field3=mlMagnitude`
  - `field4=mrMagnitude`
  - `field5=mlX`
  - `field6=mlY`
  - `field7=mrX`
  - `field8=mrY`
- Parses the server HTTP response code and returned integer `entry_id`. An `entry_id > 0` confirms successful cloud ingestion. A response of `0` denotes rate-limiting violation (< 15 seconds between posts).

---

## 4. ThingSpeak Integration, Channel Structure, and Field Mapping

### 4.1 Channel Overview
- **Channel ID:** `3465279`
- **Channel Name:** `amma-proto2`
- **Access Model:** Public read access enabled. No read API key is mandatory for GET requests, though the client architecture supports an optional `THINGSPEAK_READ_API_KEY` dart-define for private deployments.
- **REST Feed Endpoint:** `https://api.thingspeak.com/channels/3465279/feeds.json`
- **Confirmed Online Entries:** > 323 verified entries with real hardware readings.

### 4.2 Exact Field Mapping Specification

| ThingSpeak Field | Parameter Name | Data Type | Physical Unit | Description / Clinical Meaning |
|---|---|---|---|---|
| **field1** | `PL raw` | Integer | Raw ADC Counts | Left Piezo mechanical displacement / acoustic signal via ADS1115 A1 (±4.096V scale) |
| **field2** | `PR raw` | Integer | Raw ADC Counts | Right Piezo mechanical displacement / acoustic signal via ADS1115 A0 (±4.096V scale) |
| **field3** | `ML acceleration magnitude` | Float | $\text{m/s}^2$ | Left abdominal composite acceleration vector magnitude ($\sqrt{X^2+Y^2+Z^2}$) |
| **field4** | `MR acceleration magnitude` | Float | $\text{m/s}^2$ | Right abdominal composite acceleration vector magnitude ($\sqrt{X^2+Y^2+Z^2}$) |
| **field5** | `ML X` | Float | $\text{m/s}^2$ | Left MPU X-axis lateral abdominal acceleration |
| **field6** | `ML Y` | Float | $\text{m/s}^2$ | Left MPU Y-axis longitudinal/vertical abdominal acceleration |
| **field7** | `MR X` | Float | $\text{m/s}^2$ | Right MPU X-axis lateral abdominal acceleration |
| **field8** | `MR Y` | Float | $\text{m/s}^2$ | Right MPU Y-axis longitudinal/vertical abdominal acceleration |

*Note on Field 3 & 4 values:* Earth's gravitational acceleration ($\approx 9.81\ \text{m/s}^2$) is naturally present in resting magnitude readings.

---

## 5. Features That Are Implemented and Experimentally Verified

1. **Dual Spatial Sensor Array:** Operational integration of two MPU6050 IMUs at distinct I²C addresses (`0x68`, `0x69`) and two piezoelectric transducers on ADS1115 channels A0 and A1.
2. **High-Resolution Low-Noise Analog Front-End:** Verified ADS1115 conversion eliminating ESP32 internal SAR ADC Wi-Fi radio coupling and non-linearity.
3. **Firmware Decoupled Acquisition:** 10 Hz local sensor polling running concurrently with 20-second cloud uploads.
4. **Local Hardware Feedback:** Real-time SSD1306 OLED display and 115,200 baud serial telemetry.
5. **Secure Cloud Ingestion:** Working Wi-Fi connection and HTTPS upload to ThingSpeak Channel `3465279` with incrementing Entry IDs.
6. **Mobile Telemetry Ingestion (Milestone 1 Starter):** Read-only consumption of ThingSpeak feeds, JSON parsing, and baseline card presentation.

---

## 6. Features That Are Proposed But NOT Implemented

The following features appear in the original proposal, design suggestions, or future roadmap diagrams, but are **NOT** present in the working prototype:

1. **Fetal Kick Detection & Automated Kick Counting:** No digital Butterworth bandpass filter (2–20 Hz), peak detection, or dual-sensor gating is running on either the ESP32-S3 or the cloud.
2. **AI / ML Classification Layer:** No edge TinyML model, random forest, or neural network is deployed to classify fetal kicks versus maternal coughs, posture shifts, or bowel movements.
3. **Personalized Baseline & Z-Score Anomaly Detection:** No 72-hour maternal circadian baseline algorithm exists.
4. **Maternal Heart Rate (BPM) & Blood Oxygen Saturation ($\text{SpO}_2$):** The MAX30102 sensor is not wired or present in the current firmware. Any UI mockups showing maternal vitals are purely aspirational.
5. **Abdominal Skin Temperature Sensing:** MLX90614 infrared sensor is not integrated.
6. **Belt Fit / Compliance Detection:** No force-sensitive resistors (FSR) or capacitive wear-detection sensors exist.
7. **Firebase / Firestore Real-Time Backend:** The working prototype uses ThingSpeak, not Firebase or Cloud Functions.
8. **Battery Management & Duty Cycling:** Firmware runs continuously on main USB power without deep sleep or BLE beaconing.

---

## 7. Relevant Design Recommendations and Technical Limitations

### 7.1 Design Recommendations from Expert Review
- **MPU6050 Role Reassignment:** In subsequent phases, MPU6050 data must serve as a **maternal activity gate** (detecting whether the mother is walking, sitting, or still) rather than a direct kick sensor, because maternal ambulation ($0.3\text{g} - 1.0\text{g}$) easily swamps subtle fetal kicks ($0.05\text{g} - 0.15\text{g}$).
- **Sensor Transducer Upgrade:** Transitioning from rigid ceramic buzzer discs to flexible Polyvinylidene Fluoride (PVDF) piezoelectric film sewn into the belt fabric will drastically enhance acoustic skin coupling.
- **Signal Filtering:** Bandpass filtering (2–20 Hz) is required to suppress maternal heartbeat (1.2 Hz) and respiratory movements (0.3 Hz).

### 7.2 Technical Limitations of Current Setup
- **Cloud Latency vs. Local Bandwidth:** While the MCU samples at 10 Hz, ThingSpeak only logs every ~20 seconds. The cloud channel presents an **intermittent trend log**, not a continuous real-time waveform.
- **Gravitational Bias in Accelerometer Data:** Acceleration magnitude includes static $1\text{g}$ gravitational vector.
- **Absence of Fetal Movement Ground Truth:** Readings in ThingSpeak cannot be interpreted as confirmed kicks without synchronized maternal event logging or ultrasound validation.

---

## 8. Resolution of Conflicting Documentation

To maintain rigorous technical fidelity, conflicts between project artifacts are resolved according to the strict source-of-truth hierarchy:

| Topic | Proposal / Mini-Project Report | Suggestions Document | Current Firmware / IEEE Paper | Resolved Truth for Android Application |
|---|---|---|---|---|
| **Microcontroller** | ESP32 standard dual-core | ESP32-S3 recommended | ESP32-S3 verified | **ESP32-S3** is the sole controller. |
| **Sensor Complement** | 1 MPU6050, 1 Piezo, MAX30102 (pulse ox) | PVDF film, ADS1115, MLX90614 | 2 MPU6050, 2 Piezos, ADS1115, OLED; NO MAX30102 | **2 MPU6050 + 2 Piezos via ADS1115 + OLED.** Do not display HR or $\text{SpO}_2$. |
| **Cloud Backend** | Firebase Realtime DB / Firestore | Firestore triggers | ThingSpeak Channel `3465279` via HTTPS REST | **ThingSpeak REST API**. No Firebase or Firestore dependencies. |
| **Sampling Frequency** | 50 Hz internal sampling | Gated bandpass loop | 10 Hz local loop (100 ms), 20 s cloud upload | **10 Hz local acquisition, ~20 s cloud upload interval**. Display appropriate time labels. |
| **Clinical Capabilities** | Automated kick detection & alert escalation | Dual-sensor gating logic | Multi-sensor acquisition only; no kick detection | **No kick counts, scores, or alerts in app.** Strict prototype disclaimer displayed. |

---

## 9. Recommended Android App Architecture and Screens

### 9.1 Recommended App Architecture
The Android application is developed with **Flutter** (Dart 3.x), adhering to a clean, layered architecture without over-engineering:

```
lib/
├── main.dart                   # App entrypoint, Material3 theme, navigation scaffold
├── models/
│   └── sensor_reading.dart     # Immutable model for ThingSpeak feeds (fields 1-8)
├── services/
│   └── thingspeak_service.dart # HTTP client with timeout, error handling, caching
├── screens/
│   ├── overview_screen.dart    # Primary live telemetry & sensor overview cards
│   ├── trends_screen.dart      # Interactive fl_chart historical trends (Mag, ADC, Axes)
│   ├── device_screen.dart      # Hardware architecture, I2C addresses, cloud status
│   └── about_screen.dart       # Academic info, methodology, safety disclaimer
└── widgets/
    ├── metric_card.dart        # Reusable styled sensor reading card
    ├── connection_banner.dart  # Visual cloud sync and stale-data indicator
    └── chart_card.dart         # Container card with legends and touch tooltips
```

### 9.2 Initial Screens and Responsibilities

1. **Overview Screen:**
   - **Hero Metric Cards:** Dual Piezo signals (`PL`, `PR` in raw ADC counts) and dual MPU acceleration magnitudes (`ML Mag`, `MR Mag` in $\text{m/s}^2$).
   - **Multi-Axis Detail Card:** Instantaneous $X$ and $Y$ directional acceleration components.
   - **Cloud Sync & Freshness Banner:** Real-time status indicator displaying channel ID, entry count, last sync timestamp, and automatic warning when data is older than 2 minutes.
   - **Quick Trend Sparkline:** Immediate visual movement summary.

2. **Trends Screen:**
   - **Composite Acceleration Magnitude Chart:** Interactive time-series comparing Left vs. Right movement ($\text{m/s}^2$) with touch tooltips.
   - **Piezo Raw ADC Trend Chart:** Longitudinal mechanical/vibration signal plot showing baseline and transients.
   - **Directional Acceleration Chart:** $X$ and $Y$ axis trajectory comparison over recent entries.
   - **Range Filter / History Selector:** Configurable feed depth (e.g., last 30, 60, or 100 entries).

3. **Device Screen:**
   - **Hardware Telemetry Map:** Clear visual representation of ESP32-S3 pin mappings, ADS1115 ADC channels, and MPU6050 I²C addresses (`0x68`, `0x69`).
   - **Sampling Architecture Explanation:** Educational callout distinguishing 10 Hz local acquisition from ~20 s cloud ingestion.
   - **Connection Diagnostics:** Latency, status codes, and manual "Refresh Now" action.

4. **About & Safety Screen:**
   - **Research Prototype Disclaimer:** Prominent, permanent medical disclaimer emphasizing that the app is an engineering prototype and must not replace clinical consultation.
   - **Project Provenance:** Academic attribution to YCCE Department of Electronics Engineering (VLSI Design & Technology).
   - **Documentation & References:** Summary of verified prototype specifications and IEEE conference paper abstract.

### 9.3 Visual Direction & Design Tokens
- **Palette:** Maternal wellness aesthetic emphasizing serenity and clarity.
  - Deep Botanical Ink (`#183A36`) for high-contrast, accessible typography.
  - Reassuring Sage / Eucalyptus (`#2F776B`) for active states and primary accents.
  - Soft Mint Wash (`#E6F3EE`) for subtle card highlights and chips.
  - Warm Paper Surface (`#F7F8F4`) for glare-free background viewing.
  - Gentle Amber Warning (`#B77927`) for stale data warnings.
  - Coral Pink Accent (`#C87565`) for right-side sensor distinction and network errors.
- **Typography:** Modern, legible sans-serif hierarchy (Material 3 standard Roboto/Inter).
- **Interactions:** Subtle micro-animations, pull-to-refresh, haptic feedback on touch tooltips, and graceful error recovery that retains previously loaded readings.

---

## 10. Milestone-Based Implementation and Testing Plan

| Milestone | Objective | Key Deliverables & Validation Criteria |
|---|---|---|
| **M1: Environment & Project Bootstrap** | Initialize Flutter platform directories and resolve dependencies | Execute `flutter create --platforms=android .`; verify `pubspec.yaml` with `fl_chart`, `http`, `intl`; ensure zero compile errors. |
| **M2: Model & Network Service Hardening** | Verify ThingSpeak REST ingestion and error handling | Unit test `SensorReading.fromThingSpeak` on real channel data; ensure timeouts, 4xx/5xx responses, and empty fields are gracefully handled without crashing. |
| **M3: Modular UI & Screen Architecture** | Decompose monolithic UI into dedicated, maintainable screens | Implement `OverviewScreen`, `TrendsScreen`, `DeviceScreen`, and `AboutScreen` with unified Material 3 theme and responsive layouts. |
| **M4: Interactive Charting & Visual Polish** | Deliver premium trend visualization | Configure `fl_chart` with formatted axes, legends, touch tooltips, and empty-state placeholders. |
| **M5: Quality Assurance & Static Analysis** | Enforce code health and automated testing | Run `flutter analyze` with 0 issues; run `flutter test` with 100% test passing rate. |
| **M6: Android Build & Emulated Verification** | Compile debug APK and verify runtime execution | Run `flutter build apk --debug`; install and verify on active Android emulator (`sdk gphone16k x86_64`, API 37); confirm live readings match `api.thingspeak.com`. |

---

## 11. Unresolved Technical & Clinical Questions

1. **Patient Movement Gating Ground Truth:** How will future firmware differentiate maternal breathing and postural shifts from fetal movement once PVDF strips are installed?
2. **Offline Local Telemetry:** For rural environments without active Wi-Fi, will direct BLE 5.0 streaming from the ESP32-S3 to the Android app be prioritized in Milestone 2?
3. **Private Channel Key Provisioning:** In commercial production, will devices be provisioned via QR code / BLE pairing to avoid compile-time `--dart-define` secrets?
