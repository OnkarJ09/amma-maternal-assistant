import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/monitoring_session.dart';

class SessionSummaryDialog extends StatelessWidget {
  const SessionSummaryDialog({
    super.key,
    required this.session,
  });

  final MonitoringSession session;

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF2F776B);
    const ink = Color(0xFF183A36);
    const muted = Color(0xFF73827D);
    final timeFormat = DateFormat('h:mm:ss a (d MMM)');

    final peakPl = session.peakPlRaw;
    final peakPr = session.peakPrRaw;
    final peakMl = session.peakMlMagnitude;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F3EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assessment_outlined, color: teal),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Telemetry Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        Text(
                          'Targeted maternal observation record',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _summaryRow('Session ID', session.id),
              _summaryRow('Start Time', timeFormat.format(session.startTime)),
              _summaryRow(
                'End Time',
                session.endTime == null
                  ? 'In Progress'
                  : timeFormat.format(session.endTime!),
              ),
              _summaryRow('Duration', _formatDuration(session.duration)),
              _summaryRow('Ingested Entries', '${session.sampleCount} records'),
              const Divider(height: 20),
              const Text(
                'Observed Mechanical & Motion Peaks',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              _summaryRow(
                'Left Piezo (PL) Peak',
                peakPl != null
                    ? '${peakPl.toStringAsFixed(0)} ADC (${(peakPl * 0.000125).toStringAsFixed(3)}V)'
                    : '—',
              ),
              _summaryRow(
                'Right Piezo (PR) Peak',
                peakPr != null
                    ? '${peakPr.toStringAsFixed(0)} ADC (${(peakPr * 0.000125).toStringAsFixed(3)}V)'
                    : '—',
              ),
              _summaryRow(
                'Max Movement (ML)',
                peakMl != null ? '${peakMl.toStringAsFixed(2)} m/s²' : '—',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB77927)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Clinical Review Notice: Telemetry captures mechanical sensors on maternal abdomen. Accelerations include maternal posture and gravity. Must be clinically reviewed.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8B5E34), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final csv = session.toCsv();
                        Clipboard.setData(ClipboardData(text: csv));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('CSV Telemetry copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: teal,
                        side: const BorderSide(color: teal),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: teal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF73827D))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF183A36),
            ),
          ),
        ],
      ),
    );
  }
}
