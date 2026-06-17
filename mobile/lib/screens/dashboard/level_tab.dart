import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LevelTab extends StatelessWidget {
  const LevelTab({super.key});

  static const _levels = [
    _LevelData('Good', '0-50', Color(0xFF00B074),
        'Air quality is satisfactory. No risk to health.'),
    _LevelData('Moderate', '51-100', Color(0xFFF5A623),
        'Acceptable air quality. Sensitive groups may experience minor discomfort.'),
    _LevelData('Unhealthy', '101-200', Color(0xFFFF6B35),
        'Unhealthy for sensitive groups. May cause respiratory issues for some individuals.'),
    _LevelData('Unhealthy', '201-300', Color(0xFFE53935),
        'General public may experience health effects. Sensitive groups may experience serious health effects.'),
    _LevelData('Severe', '300+', Color(0xFF7B1FA2),
        'Serious risk of respiratory effects.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Air Quality Index Scale',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Learn about your Air Quality Index (AQI)\ncategories and their implications',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _levels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _LevelCard(data: _levels[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final _LevelData data;

  const _LevelCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 52,
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                data.range,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              data.description,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelData {
  final String label;
  final String range;
  final Color color;
  final String description;

  const _LevelData(this.label, this.range, this.color, this.description);
}
