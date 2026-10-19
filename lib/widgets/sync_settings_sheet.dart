import 'package:flutter/material.dart';

class SyncSettingsSheet extends StatelessWidget {
  const SyncSettingsSheet({
    super.key,
    required this.currentIntervalSeconds,
    required this.currentStaleMinutes,
    required this.onIntervalChanged,
    required this.onStaleMinutesChanged,
  });

  final int currentIntervalSeconds;
  final int currentStaleMinutes;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<int> onStaleMinutesChanged;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF2F776B);
    const ink = Color(0xFF183A36);
    const muted = Color(0xFF73827D);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4E7DF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Telemetry Sync Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure automatic polling rate and freshness limits for ThingSpeak channel 3465279.',
            style: TextStyle(fontSize: 12.5, color: muted, height: 1.35),
          ),
          const SizedBox(height: 20),
          const Text(
            'Auto-Refresh Interval',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'The ESP32-S3 uploads roughly every 20 seconds.',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _buildIntervalChip(0, 'Manual Only', currentIntervalSeconds == 0),
              _buildIntervalChip(20, '20 Seconds', currentIntervalSeconds == 20),
              _buildIntervalChip(30, '30 Seconds', currentIntervalSeconds == 30),
              _buildIntervalChip(60, '1 Minute', currentIntervalSeconds == 60),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Stale-Data Warning Threshold',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Show warning when latest cloud reading is older than:',
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _buildStaleChip(2, '2 Minutes', currentStaleMinutes == 2),
              _buildStaleChip(5, '5 Minutes', currentStaleMinutes == 5),
              _buildStaleChip(10, '10 Minutes', currentStaleMinutes == 10),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalChip(int seconds, String label, bool isSelected) {
    const teal = Color(0xFF2F776B);
    const mint = Color(0xFFE6F3EE);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onIntervalChanged(seconds),
      selectedColor: mint,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? teal : const Color(0xFF183A36),
      ),
      side: BorderSide(
        color: isSelected ? teal : const Color(0xFFE0E5E2),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildStaleChip(int minutes, String label, bool isSelected) {
    const amber = Color(0xFFB77927);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onStaleMinutesChanged(minutes),
      selectedColor: const Color(0xFFFFF3E0),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? amber : const Color(0xFF183A36),
      ),
      side: BorderSide(
        color: isSelected ? amber : const Color(0xFFE0E5E2),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
