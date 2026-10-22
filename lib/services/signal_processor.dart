import 'dart:math';

import '../models/sensor_reading.dart';

enum PiezoChannel {
  left,
  right,
}

class KickEvent {
  const KickEvent({
    required this.index,
    required this.timestamp,
    required this.amplitude,
    required this.dominantChannel,
    required this.dynamicMotion,
  });

  final int index;
  final DateTime timestamp;
  final double amplitude;
  final PiezoChannel dominantChannel;
  final double dynamicMotion;
}

class FilteredPoint {
  FilteredPoint({
    required this.index,
    required this.timestamp,
    required this.rawPl,
    required this.filteredPl,
    this.rawPr = 0.0,
    this.filteredPr = 0.0,
    required this.effectiveSpike,
    required this.maternalMotionMagnitude,
    required this.isMotherResting,
    required this.isCandidateKick,
    this.dominantChannel = PiezoChannel.left,
    this.rejectionReason,
  });

  final int index;
  final DateTime timestamp;
  final double rawPl;
  final double filteredPl;
  final double rawPr;
  final double filteredPr;
  final double effectiveSpike;
  final double maternalMotionMagnitude;
  final bool isMotherResting;
  final bool isCandidateKick;
  final PiezoChannel dominantChannel;
  final String? rejectionReason;
}

class SignalAnalysisReport {
  SignalAnalysisReport({
    required this.points,
    required this.candidateKickCount,
    required this.candidateKicksList,
    required this.rejectedArtifactCount,
    required this.motherRestingPercentage,
  });

  final List<FilteredPoint> points;
  final int candidateKickCount;
  final List<KickEvent> candidateKicksList;
  final int rejectedArtifactCount;
  final double motherRestingPercentage;
}

class SignalProcessor {
  const SignalProcessor();

  /// Evaluates sensor readings using the dual-sensor gating rule:
  /// 1. Bilateral Piezo transient (max(PL, PR)) exceeds [piezoThreshold]
  /// 2. Mother dynamic motion (|accel(t) - rolling_baseline|) is below [maternalMotionThreshold]
  /// 3. Minimum 2-second refractory inter-kick interval
  SignalAnalysisReport analyzeReadings(
    List<SensorReading> readings, {
    double piezoThreshold = 1800.0,
    double maternalMotionThreshold = 0.35,
    bool enableFiltering = true,
    bool enablePiezoGate = true,
    bool enableMotionGate = true,
  }) {
    if (readings.isEmpty) {
      return SignalAnalysisReport(
        points: [],
        candidateKickCount: 0,
        candidateKicksList: [],
        rejectedArtifactCount: 0,
        motherRestingPercentage: 100.0,
      );
    }

    final points = <FilteredPoint>[];
    final candidateKicksList = <KickEvent>[];
    int candidateKicks = 0;
    int rejectedArtifacts = 0;
    int restingCount = 0;
    DateTime? lastCandidateKickTime;

    // Moving average / baseline estimation for both piezos
    double runningPlBaseline = readings.first.plRaw ?? 0.0;
    double runningPrBaseline = readings.first.prRaw ?? 0.0;

    // Moving average baseline estimation for maternal accelerometers (ML and MR)
    // Tracks uncalibrated sensor offsets and gravity tilt so dynamic motion
    // is measured honestly without static gravity bias.
    double runningMlBaseline = readings.first.mlMagnitude ?? 9.80;
    double runningMrBaseline = readings.first.mrMagnitude ?? runningMlBaseline;

    for (var i = 0; i < readings.length; i++) {
      final r = readings[i];
      final rawPl = r.plRaw ?? 0.0;
      final rawPr = r.prRaw ?? 0.0;

      // Digital baseline tracking (leaky integrator) for PL and PR
      runningPlBaseline = runningPlBaseline * 0.85 + rawPl * 0.15;
      runningPrBaseline = runningPrBaseline * 0.85 + rawPr * 0.15;

      final highPassedPl = rawPl - runningPlBaseline;
      final highPassedPr = rawPr - runningPrBaseline;

      final filteredPl = enableFiltering ? highPassedPl.abs() : rawPl;
      final filteredPr = enableFiltering ? highPassedPr.abs() : rawPr;

      final effectiveSpike = max(filteredPl, filteredPr);
      final dominantChannel =
          filteredPl >= filteredPr ? PiezoChannel.left : PiezoChannel.right;

      // Maternal dynamic motion: measures high-frequency maternal movement
      // by computing deviation from slow rolling baseline.
      final mlMag = r.mlMagnitude ?? 9.80;
      final mrMag = r.mrMagnitude ?? mlMag;

      runningMlBaseline = runningMlBaseline * 0.90 + mlMag * 0.10;
      runningMrBaseline = runningMrBaseline * 0.90 + mrMag * 0.10;

      final dynamicMl = (mlMag - runningMlBaseline).abs();
      final dynamicMr = (mrMag - runningMrBaseline).abs();
      final dynamicMotion = max(dynamicMl, dynamicMr);

      final isMotherResting = dynamicMotion <= maternalMotionThreshold;
      if (isMotherResting) restingCount++;

      bool isCandidate = false;
      String? rejectionReason;

      if (enablePiezoGate && enableMotionGate) {
        // Dual-sensor gating: Piezo spike gated by maternal quietude
        final isSpike = effectiveSpike >= piezoThreshold;
        if (isSpike) {
          if (!isMotherResting) {
            rejectedArtifacts++;
            rejectionReason =
                'Mother active (${dynamicMotion.toStringAsFixed(2)} m/s² > ${maternalMotionThreshold.toStringAsFixed(2)})';
          } else if (lastCandidateKickTime != null &&
              r.timestamp.difference(lastCandidateKickTime).inSeconds < 2) {
            rejectedArtifacts++;
            rejectionReason = 'Refractory window (< 2s inter-kick)';
          } else {
            isCandidate = true;
            candidateKicks++;
            lastCandidateKickTime = r.timestamp;
            candidateKicksList.add(
              KickEvent(
                index: i,
                timestamp: r.timestamp,
                amplitude: effectiveSpike,
                dominantChannel: dominantChannel,
                dynamicMotion: dynamicMotion,
              ),
            );
          }
        }
      } else if (enablePiezoGate && !enableMotionGate) {
        // Piezo-only mode: Mother motion gate is completely disabled
        final isSpike = effectiveSpike >= piezoThreshold;
        if (isSpike) {
          if (lastCandidateKickTime != null &&
              r.timestamp.difference(lastCandidateKickTime).inSeconds < 2) {
            rejectedArtifacts++;
            rejectionReason = 'Refractory window (< 2s inter-kick)';
          } else {
            isCandidate = true;
            candidateKicks++;
            lastCandidateKickTime = r.timestamp;
            candidateKicksList.add(
              KickEvent(
                index: i,
                timestamp: r.timestamp,
                amplitude: effectiveSpike,
                dominantChannel: dominantChannel,
                dynamicMotion: dynamicMotion,
              ),
            );
          }
        }
      } else if (!enablePiezoGate && enableMotionGate) {
        // Motion-only mode: Piezo threshold is completely disabled
        // Evaluates high-frequency dynamic acceleration spikes on ML/MR
        final isMotionSpike = dynamicMotion >= maternalMotionThreshold;
        if (isMotionSpike) {
          if (lastCandidateKickTime != null &&
              r.timestamp.difference(lastCandidateKickTime).inSeconds < 2) {
            rejectedArtifacts++;
            rejectionReason = 'Refractory window (< 2s inter-kick)';
          } else {
            isCandidate = true;
            candidateKicks++;
            lastCandidateKickTime = r.timestamp;
            candidateKicksList.add(
              KickEvent(
                index: i,
                timestamp: r.timestamp,
                amplitude: effectiveSpike > 0 ? effectiveSpike : dynamicMotion * 1000,
                dominantChannel: dominantChannel,
                dynamicMotion: dynamicMotion,
              ),
            );
          }
        }
      }

      points.add(
        FilteredPoint(
          index: i,
          timestamp: r.timestamp,
          rawPl: rawPl,
          filteredPl: filteredPl,
          rawPr: rawPr,
          filteredPr: filteredPr,
          effectiveSpike: effectiveSpike,
          maternalMotionMagnitude: dynamicMotion,
          isMotherResting: isMotherResting,
          isCandidateKick: isCandidate,
          dominantChannel: dominantChannel,
          rejectionReason: rejectionReason,
        ),
      );
    }

    final restingPercentage = (restingCount / readings.length) * 100.0;

    return SignalAnalysisReport(
      points: points,
      candidateKickCount: candidateKicks,
      candidateKicksList: candidateKicksList,
      rejectedArtifactCount: rejectedArtifacts,
      motherRestingPercentage: restingPercentage,
    );
  }
}
