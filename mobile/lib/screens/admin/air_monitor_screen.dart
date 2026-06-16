import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../dashboard/widgets/aqi_utils.dart';
import '../../providers/air_quality_provider.dart';
import '../../providers/device_provider.dart';
import '../../services/mqtt_service.dart';
import '../../theme/app_theme.dart';

class AirMonitorScreen extends StatelessWidget {
  const AirMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AirQualityProvider, DeviceProvider>(
      builder: (context, aq, deviceProvider, _) {
        final live = aq.live;
        final pm25 = live?.pm2_5 ?? 0.0;
        final aqi = live?.aqi ?? 0;
        final aqiColor = AqiUtils.colorForAqi(aqi);
        final aqiLabel = AqiUtils.labelForAqi(aqi);
        final totalDevices = deviceProvider.devices.length;

        return Scaffold(
          backgroundColor: Colors.white,
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(
                              Icons.arrow_back_ios_new_rounded, size: 16),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        aq.isLiveConnected ? Icons.wifi : Icons.wifi_off,
                        color: aq.isLiveConnected
                            ? AppTheme.primary
                            : Colors.grey,
                        size: 22,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smart Air Monitor',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        Text('Air quality Overview',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade500)),
                        const SizedBox(height: 24),
                        Center(
                          child: Text('All Stations',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 24),
                        if (live == null)
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.sensors_off,
                                    size: 48,
                                    color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text('Waiting for live data...',
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey)),
                              ],
                            ),
                          )
                        else ...[
                          Center(
                            child: SizedBox(
                              height: 200,
                              width: 200,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      startDegreeOffset: -90,
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 70,
                                      sections: [
                                        PieChartSectionData(
                                          value: pm25.clamp(0, 100),
                                          color: aqiColor,
                                          radius: 20,
                                          showTitle: false,
                                        ),
                                        PieChartSectionData(
                                          value: (100 - pm25).clamp(0, 100),
                                          color: Colors.grey.shade200,
                                          radius: 20,
                                          showTitle: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('PM2.5',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey.shade500)),
                                      Text(
                                        pm25.toStringAsFixed(1),
                                        style: GoogleFonts.poppins(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w800),
                                      ),
                                      Text('μg/m³',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8F1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(aqiLabel,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryTile(
                                    value: '$totalDevices',
                                    label: 'Devices',
                                    icon: Icons.devices_other_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryTile(
                                    value: '$aqi',
                                    label: 'AQI',
                                    icon: Icons.air),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryTile(
                                    value:
                                        '${live.temperature.toInt()}°C',
                                    label: 'Temperature',
                                    icon: Icons.thermostat_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryTile(
                                    value: '${live.humidity.toInt()}%',
                                    label: 'Humidity',
                                    icon: Icons.water_drop_outlined),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _LiveMetricsGrid(live: live),
                        ],
                      ],
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
}

class _LiveMetricsGrid extends StatelessWidget {
  final AirQualityPayload live;
  const _LiveMetricsGrid({required this.live});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        _DeviceDonut(
            label: 'PM 2.5',
            value: live.pm2_5,
            max: 500,
            color: const Color(0xFFE53935)),
        _DeviceDonut(
            label: 'PM 1.0',
            value: live.pm1_0,
            max: 500,
            color: const Color(0xFFF5A623)),
        _DeviceDonut(
            label: 'PM 10',
            value: live.pm10,
            max: 500,
            color: const Color(0xFFFF6B35)),
        _DeviceDonut(
            label: 'Gas PPM',
            value: live.gasPpm,
            max: 1000,
            color: const Color(0xFF7B1FA2)),
        _DeviceDonut(
            label: 'Temperature',
            value: live.temperature,
            max: 60,
            color: const Color(0xFFE53935)),
        _DeviceDonut(
            label: 'Humidity',
            value: live.humidity,
            max: 100,
            color: Colors.blue),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _SummaryTile(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Icon(icon, size: 28, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _DeviceDonut extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _DeviceDonut(
      {required this.label,
      required this.value,
      required this.max,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 0,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(
                        value: pct * 100,
                        color: color,
                        radius: 12,
                        showTitle: false),
                    PieChartSectionData(
                        value: (1 - pct) * 100,
                        color: Colors.grey.shade200,
                        radius: 12,
                        showTitle: false),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${value.toInt()}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w700)),
                  Text('val',
                      style: GoogleFonts.poppins(
                          fontSize: 8, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 10)),
      ],
    );
  }
}
