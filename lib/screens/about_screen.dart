import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        const Text(
          'Settings & About',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF183A36),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Project governance, clinical boundaries, and engineering roadmap.',
          style: TextStyle(fontSize: 13, color: Color(0xFF73827D)),
        ),
        const SizedBox(height: 16),
        _buildMedicalDisclaimerCard(),
        const SizedBox(height: 16),
        _buildProjectInfoCard(),
        const SizedBox(height: 16),
        _buildRoadmapCard(),
        const SizedBox(height: 16),
        _buildAppInfoCard(),
      ],
    );
  }

  Widget _buildMedicalDisclaimerCard() {
    return Card(
      color: const Color(0xFFFFF7ED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFFEDD5)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB77927), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Important Clinical Disclaimer',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF8B5E34),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'AMMA (AI-Enabled Maternal Monitoring Assistant) is an engineering research prototype designed for sensor telemetry acquisition.\n\n'
              '• The current prototype DOES NOT detect, validate, or count fetal kicks.\n'
              '• Acceleration magnitude reflects sensor motion and Earth gravity, not direct fetal kick count.\n'
              '• This prototype does not measure maternal heart rate or SpO2.\n'
              '• This software and hardware must NEVER be used for diagnostic purposes or to assess fetal wellbeing.\n\n'
              'If you notice reduced fetal movements or have any concern regarding your pregnancy, contact your doctor or maternity hospital immediately without delay.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF785329),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.school_rounded, color: Color(0xFF2F776B)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Academic Attribution',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF183A36),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _infoRow('Institution', 'Yeshwantrao Chavan College of Engineering (YCCE)'),
            _infoRow('Department', 'Electronics Engineering (VLSI Design & Technology)'),
            _infoRow('Project Guide', 'Dr. Prachi P. Palsodkar'),
            _infoRow(
              'Development Team',
              'Yash Izate (VLSI-69)\nOnkar Joshi (VLSI-48)\nShivam Salve (VLSI-56)\nKanchan Gawande (VLSI-11)\nOjas Deshpande (VLSI-44)',
            ),
            _infoRow('Academic Year', '2026 – 2027'),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_rounded, color: Color(0xFF2F776B)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Development Roadmap',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF183A36),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            _RoadmapItem(
              status: 'Completed',
              isDone: true,
              title: 'Phase 1: Multi-Sensor Ingestion & Telemetry',
              description:
                  'ESP32-S3 + ADS1115 + Dual MPU6050 + OLED local feedback and verified ThingSpeak HTTPS logging.',
            ),
            SizedBox(height: 10),
            _RoadmapItem(
              status: 'Planned',
              isDone: false,
              title: 'Phase 2: Signal Filtering & Gating',
              description:
                  '2–20 Hz bandpass filter on piezo signals to reject maternal heart/breathing; MPU-based maternal posture gating.',
            ),
            SizedBox(height: 10),
            _RoadmapItem(
              status: 'Planned',
              isDone: false,
              title: 'Phase 3: 72-Hour Personal Baseline',
              description:
                  'Personalized circadian z-score movement model with clinical ACOG cold-start baseline.',
            ),
            SizedBox(height: 10),
            _RoadmapItem(
              status: 'Planned',
              isDone: false,
              title: 'Phase 4: Edge TinyML & Direct BLE 5.0',
              description:
                  'On-device kick-classification inference and real-time smartphone relay over Bluetooth Low Energy.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF2F776B)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'System Specifications',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF183A36),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('App Name', 'AMMA Companion'),
            _infoRow('Version', '0.1.0+1 (Milestone 1)'),
            _infoRow('Framework', 'Flutter 3.47.5 · Dart 3.13.4'),
            _infoRow('Design System', 'Material 3 (Maternal Wellness Palette)'),
            _infoRow('Target Platform', 'Android (API 34+)'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF73827D))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF183A36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapItem extends StatelessWidget {
  const _RoadmapItem({
    required this.status,
    required this.isDone,
    required this.title,
    required this.description,
  });

  final String status;
  final bool isDone;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isDone ? const Color(0xFF2F776B) : const Color(0xFF73827D),
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDone ? const Color(0xFF183A36) : const Color(0xFF73827D),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDone ? const Color(0xFFE6F3EE) : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isDone ? const Color(0xFF2F776B) : const Color(0xFF73827D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 11, color: Color(0xFF73827D), height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
