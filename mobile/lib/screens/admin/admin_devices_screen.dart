import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../dashboard/widgets/aqi_utils.dart';
import '../../providers/air_quality_provider.dart';
import '../../providers/device_provider.dart';
import '../../services/device_service.dart';
import '../../services/mqtt_service.dart';
import '../../theme/app_theme.dart';

class AdminDevicesScreen extends StatefulWidget {
  const AdminDevicesScreen({super.key});

  @override
  State<AdminDevicesScreen> createState() => _AdminDevicesScreenState();
}

class _AdminDevicesScreenState extends State<AdminDevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DeviceProvider, AirQualityProvider>(
      builder: (context, deviceProvider, aqProvider, _) {
        final pm25History = aqProvider
            .historyForField('pm2_5')
            .reversed
            .take(7)
            .toList()
            .reversed
            .toList();

        final hasHistory = pm25History.isNotEmpty;
        final maxY = hasHistory
            ? pm25History
                    .map((p) => p.value)
                    .reduce((a, b) => a > b ? a : b)
                    .ceilToDouble() +
                10
            : 100.0;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('PM2.5 Levels (Recent)',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text('Last 7 pts',
                                style: GoogleFonts.poppins(fontSize: 13)),
                            const SizedBox(width: 6),
                            const Icon(Icons.bar_chart,
                                color: AppTheme.primary, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: !hasHistory
                        ? Center(
                            child: Text('No history data yet',
                                style: GoogleFonts.poppins(
                                    color: Colors.grey)))
                        : BarChart(
                            BarChartData(
                              maxY: maxY,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: maxY / 5,
                                getDrawingHorizontalLine: (_) => FlLine(
                                    color: Colors.grey.shade100,
                                    strokeWidth: 1),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: maxY / 5,
                                    reservedSize: 32,
                                    getTitlesWidget: (v, _) => Text(
                                        '${v.toInt()}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.grey.shade500)),
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      if (i < 0 ||
                                          i >= pm25History.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final t = pm25History[i].time;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Text(
                                            '${t.hour}:${t.minute.toString().padLeft(2, '0')}',
                                            style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                color:
                                                    Colors.grey.shade600)),
                                      );
                                    },
                                    reservedSize: 24,
                                  ),
                                ),
                              ),
                              barGroups:
                                  pm25History.asMap().entries.map((e) {
                                final color =
                                    AqiUtils.colorForAqi(_pm25ToAqi(e.value.value));
                                return BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: e.value.value,
                                      color: color,
                                      width: 18,
                                      borderRadius:
                                          const BorderRadius.vertical(
                                              top: Radius.circular(6)),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Devices',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary)),
                      Text('${deviceProvider.devices.length} total',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (deviceProvider.isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary),
                    )
                  else if (deviceProvider.devices.isEmpty)
                    Center(
                      child: Text('No devices registered',
                          style: GoogleFonts.poppins(color: Colors.grey)),
                    )
                  else
                    ...deviceProvider.devices.map(
                      (device) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DeviceCard(
                          device: device,
                          live: aqProvider.live?.device == device.deviceId
                              ? aqProvider.live
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static int _pm25ToAqi(double pm25) {
    if (pm25 <= 12.0) return ((pm25 / 12.0) * 50).round();
    if (pm25 <= 35.4) return (51 + ((pm25 - 12.1) / 23.3) * 49).round();
    if (pm25 <= 55.4) return (101 + ((pm25 - 35.5) / 19.9) * 49).round();
    return (151 + ((pm25 - 55.5) / 94.9) * 49).round().clamp(151, 500);
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final AirQualityPayload? live;

  const _DeviceCard({required this.device, this.live});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(device.name,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? const Color(0xFFE8F8F1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  device.isOnline ? 'Online' : 'Offline',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: device.isOnline
                          ? AppTheme.primary
                          : Colors.grey),
                ),
              ),
            ],
          ),
          if (device.location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(device.location,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
          if (live != null) ...[
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _DeviceDonut(
                    label: 'PM 2.5',
                    value: live!.pm2_5,
                    max: 500,
                    color: const Color(0xFFE53935)),
                _DeviceDonut(
                    label: 'PM 10',
                    value: live!.pm10,
                    max: 500,
                    color: const Color(0xFFF5A623)),
                _DeviceDonut(
                    label: 'Gas',
                    value: live!.gasPpm,
                    max: 1000,
                    color: const Color(0xFF7B1FA2)),
                _DeviceDonut(
                    label: 'Temp',
                    value: live!.temperature,
                    max: 60,
                    color: const Color(0xFFE53935)),
                _DeviceDonut(
                    label: 'Humidity',
                    value: live!.humidity,
                    max: 100,
                    color: Colors.blue),
                _DeviceDonut(
                    label: 'AQI',
                    value: live!.aqi.toDouble(),
                    max: 500,
                    color: AqiUtils.colorForAqi(live!.aqi)),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('No live data for this device',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade400)),
          ],
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
