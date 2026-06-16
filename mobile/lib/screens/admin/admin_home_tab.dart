import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../dashboard/widgets/aqi_utils.dart';
import '../../providers/air_quality_provider.dart';
import '../../services/mqtt_service.dart';
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import 'air_monitor_screen.dart';

class AdminHomeTab extends StatelessWidget {
  const AdminHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AirQualityProvider>(
      builder: (context, aq, _) {
        final live = aq.live;
        final now = DateTime.now();
        final dateStr =
            '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}, ${now.year},'
            ' ${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

        return Scaffold(
          backgroundColor: AppTheme.primary,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.menu, color: Colors.white, size: 24),
                      const Icon(Icons.air_rounded,
                          color: Colors.white, size: 28),
                      const Icon(Icons.search, color: Colors.white, size: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, Admin!',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Current Air Quality',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4FAF7),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: live == null
                        ? _buildPlaceholder()
                        : SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 20, 16, 24),
                            child: Column(
                              children: [
                                _WeatherCard(
                                  location: live.device,
                                  dateStr: dateStr,
                                  temperature: live.temperature.toInt(),
                                  humidity: live.humidity.toInt(),
                                ),
                                const SizedBox(height: 16),
                                _AirQualityCard(
                                  payload: live,
                                  onDashboard: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          DashboardScreen(payload: live),
                                    ),
                                  ),
                                  onAirMonitor: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const AirMonitorScreen()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 12),
        ],
      ),
    );
  }

  static String _weekday(int d) => const [
        '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
      ][d];
  static String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

class _WeatherCard extends StatelessWidget {
  final String location;
  final String dateStr;
  final int temperature;
  final int humidity;

  const _WeatherCard({
    required this.location,
    required this.dateStr,
    required this.temperature,
    required this.humidity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(location,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(dateStr,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$temperature°C',
                      style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text('Live Reading',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.white70)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.sensors, size: 64, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.water_drop_outlined,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text('$humidity%',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(width: 4),
              Text('Humidity',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AirQualityCard extends StatelessWidget {
  final AirQualityPayload payload;
  final VoidCallback onDashboard;
  final VoidCallback onAirMonitor;

  const _AirQualityCard({
    required this.payload,
    required this.onDashboard,
    required this.onAirMonitor,
  });

  @override
  Widget build(BuildContext context) {
    final aqi = payload.aqi;
    final label = AqiUtils.labelForAqi(aqi);
    final updatedLabel =
        'Live · ${payload.receivedAt.hour}:${payload.receivedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Air quality',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade500)),
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AqiUtils.colorForAqi(aqi))),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDashboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('View Dashboard',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Metric('PM2.5', payload.pm2_5.toStringAsFixed(1)),
              _Metric('PM10', payload.pm10.toStringAsFixed(1)),
              _Metric('Gas', '${payload.gasPpm.toInt()}'),
              _Metric('Temp', '${payload.temperature.toInt()}°C'),
              _Metric('AQI', '$aqi'),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onAirMonitor,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sensors, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Smart Air Monitor',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
              child: Text(updatedLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.grey.shade400))),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: Colors.grey.shade500)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
