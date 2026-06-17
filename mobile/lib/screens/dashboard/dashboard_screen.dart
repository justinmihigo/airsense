import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dashboard/widgets/aqi_utils.dart';
import '../../dashboard/widgets/stat_chip.dart';
import '../../services/mqtt_service.dart';
import '../../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  final AirQualityPayload payload;

  const DashboardScreen({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final aqi = payload.aqi;
    final color = AqiUtils.colorForAqi(aqi);
    final label = AqiUtils.labelForAqi(aqi);
    final now = payload.receivedAt;
    final updatedLabel =
        'Live · ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          updatedLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      const Divider(height: 20),
                      Text(
                        payload.device,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const Spacer(),
                          _AqiCircle(value: aqi, label: 'AQI', color: color),
                          const SizedBox(width: 12),
                          _AqiCircle(
                            value: payload.pm2_5.toInt(),
                            label: 'PM2.5',
                            color: AppTheme.primary,
                            hasInfo: true,
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatChip(
                              label: 'PM1.0',
                              value: payload.pm1_0.toStringAsFixed(1),
                              unit: 'μg/m³'),
                          StatChip(
                              label: 'PM2.5',
                              value: payload.pm2_5.toStringAsFixed(1),
                              unit: 'μg/m³'),
                          StatChip(
                              label: 'PM10',
                              value: payload.pm10.toStringAsFixed(1),
                              unit: 'μg/m³'),
                          StatChip(
                              label: 'Gas',
                              value: '${payload.gasPpm.toInt()}',
                              unit: 'ppm'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatChip(
                              label: 'Temperature',
                              value: '${payload.temperature.toInt()}',
                              unit: '°C'),
                          StatChip(
                              label: 'Humidity',
                              value: '${payload.humidity.toInt()}',
                              unit: '%'),
                          StatChip(label: 'AQI', value: '$aqi', unit: 'US'),
                          StatChip(
                              label: 'Status',
                              value: label.split(' ').first,
                              unit: ''),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        'Health Recommendations',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          _RecommendationItem(
                            icon: Icons.air_outlined,
                            label: 'Air Purifier',
                            detail: 'Not required at this time',
                          ),
                          _RecommendationItem(
                            icon: Icons.directions_run_rounded,
                            label: 'Indoor Activity',
                            detail: 'Limit strenuous indoor activities.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          _RecommendationItem(
                            icon: Icons.window_outlined,
                            label: 'Ventilation',
                            detail: 'Open windows when AQI is good.',
                          ),
                          _RecommendationItem(
                            icon: Icons.masks_outlined,
                            label: 'Mask',
                            detail:
                                'Use masks when air quality is unhealthy.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(0xFFD4E8D8)),
                                const SizedBox(width: 10),
                                Text(
                                  'Sensitive individuals',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              aqi <= 50
                                  ? 'Air quality is suitable for normal activities. Ensure adequate ventilation.'
                                  : aqi <= 100
                                      ? 'Unusually sensitive people should consider reducing prolonged outdoor exertion.'
                                      : 'People with respiratory conditions should limit exposure.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _AqiCircle extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  final bool hasInfo;

  const _AqiCircle({
    required this.value,
    required this.label,
    required this.color,
    this.hasInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        if (hasInfo)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline,
                  size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _RecommendationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;

  const _RecommendationItem({
    required this.icon,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 11, color: Colors.grey.shade500, height: 1.4),
          ),
        ],
      ),
    );
  }
}
