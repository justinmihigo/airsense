import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../dashboard/widgets/aqi_utils.dart';
import '../../models/aqi_report.dart';
import '../../providers/air_quality_provider.dart';
import '../../providers/device_provider.dart';
import '../../services/influx_service.dart';
import '../../theme/app_theme.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  int _view = 0;

  void _showSaveReportSheet(BuildContext context, AqiReport weekly, AqiReport monthly) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SaveReportSheet(weeklyReport: weekly, monthlyReport: monthly),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AirQualityProvider, DeviceProvider>(
      builder: (context, aqProvider, deviceProvider, _) {
        final now = DateTime.now();
        final updatedLabel =
            'Last Updated ${now.hour}:${now.minute.toString().padLeft(2, '0')}, '
            '${_monthLabel(now.month)} ${now.day}, ${now.year}';

        final weekly = _buildWeeklyReport(aqProvider.history);
        final monthly = _buildMonthlyReport(aqProvider.history);

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(updatedLabel,
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showSaveReportSheet(context, weekly, monthly),
                        icon: const Icon(Icons.download_outlined, size: 14),
                        label: Text('Save Report',
                            style: GoogleFonts.poppins(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _ViewToggle(
                          label: 'Devices',
                          active: _view == 0,
                          onTap: () => setState(() => _view = 0)),
                      const SizedBox(width: 8),
                      _ViewToggle(
                          label: 'Levels',
                          active: _view == 1,
                          onTap: () => setState(() => _view = 1)),
                      const SizedBox(width: 8),
                      _ViewToggle(
                          label: 'Reports',
                          active: _view == 2,
                          onTap: () => setState(() => _view = 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: IndexedStack(
                    index: _view,
                    children: [
                      _DevicesView(
                          deviceProvider: deviceProvider,
                          aqProvider: aqProvider),
                      _LevelsView(aqProvider: aqProvider),
                      _ReportsView(
                          weekly: weekly,
                          monthly: monthly,
                          onSave: () =>
                              _showSaveReportSheet(context, weekly, monthly)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _monthLabel(int month) {
    const labels = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return labels[month - 1];
  }

  static AqiReport _buildWeeklyReport(List<InfluxPoint> history) {
    final pm25 = history.where((p) => p.field == 'pm2_5').toList();
    if (pm25.isEmpty) {
      return AqiReport(
        title: 'Weekly Report',
        subtitle: 'No data yet',
        peakAqi: 0,
        peakDate: DateTime.now(),
        points: const [],
      );
    }
    final now = DateTime.now();
    final Map<String, List<double>> byDay = {};
    for (var p in pm25) {
      if (now.difference(p.time).inDays <= 7) {
        final label = _weekDay(p.time.weekday);
        byDay.putIfAbsent(label, () => []).add(p.value);
      }
    }
    final points = byDay.entries
        .map((e) => AqiDataPoint(
            label: e.key,
            value: e.value.reduce((a, b) => a + b) / e.value.length))
        .toList();
    final peak = points.isEmpty
        ? 0.0
        : points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return AqiReport(
      title: 'Weekly Report',
      subtitle: 'Avg PM2.5 per day (last 7 days)',
      peakAqi: peak.round(),
      peakDate: now,
      points: points,
    );
  }

  static AqiReport _buildMonthlyReport(List<InfluxPoint> history) {
    final pm25 = history.where((p) => p.field == 'pm2_5').toList();
    if (pm25.isEmpty) {
      return AqiReport(
        title: 'Monthly Report',
        subtitle: 'No data yet',
        peakAqi: 0,
        peakDate: DateTime.now(),
        points: const [],
      );
    }
    final Map<int, List<double>> byHour = {};
    for (var p in pm25) {
      byHour.putIfAbsent(p.time.hour, () => []).add(p.value);
    }
    final points = byHour.entries
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final dataPoints = points
        .map((e) => AqiDataPoint(
            label: '${e.key}h',
            value: e.value.reduce((a, b) => a + b) / e.value.length))
        .toList();
    final peak = dataPoints.isEmpty
        ? 0.0
        : dataPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return AqiReport(
      title: 'Hourly Report',
      subtitle: 'Avg PM2.5 by hour (last 24h)',
      peakAqi: peak.round(),
      peakDate: DateTime.now(),
      points: dataPoints,
    );
  }

  static String _weekDay(int d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(d - 1).clamp(0, 6)];
  }
}

class _ViewToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ViewToggle(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _DevicesView extends StatelessWidget {
  final DeviceProvider deviceProvider;
  final AirQualityProvider aqProvider;

  const _DevicesView(
      {required this.deviceProvider, required this.aqProvider});

  @override
  Widget build(BuildContext context) {
    final devices = deviceProvider.devices;

    if (deviceProvider.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (devices.isEmpty) {
      return Center(
        child: Text('No devices registered',
            style: GoogleFonts.poppins(color: Colors.grey)),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => deviceProvider.refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: devices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final device = devices[i];
          final live = aqProvider.live?.device == device.deviceId
              ? aqProvider.live
              : null;
          final aqi = live?.aqi ?? 0;
          final color = AqiUtils.colorForAqi(aqi);

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16)),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sensors,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 22),
                        const SizedBox(height: 2),
                        Text(
                          live != null
                              ? '${live.temperature.toInt()}°C'
                              : '—',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AqiUtils.labelForAqi(aqi),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          live != null ? '$aqi' : '—',
                          style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        Text('US AQI',
                            style: GoogleFonts.poppins(
                                fontSize: 9, color: Colors.white70)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(device.location,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                          Text(device.name,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (live != null) ...[
                            Row(children: [
                              const Icon(Icons.thermostat_outlined,
                                  size: 14, color: Colors.red),
                              const SizedBox(width: 2),
                              Text(
                                  '${live.temperature.toInt()}°C',
                                  style:
                                      GoogleFonts.poppins(fontSize: 11)),
                              const SizedBox(width: 8),
                              _S('${live.pm2_5.toInt()}', 'PM2.5'),
                              const SizedBox(width: 8),
                              _S('${live.pm10.toInt()}', 'PM10'),
                              const SizedBox(width: 8),
                              _S('${live.gasPpm.toInt()}', 'Gas'),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.water_drop_outlined,
                                  size: 14, color: Colors.blueAccent),
                              const SizedBox(width: 2),
                              Text(
                                  '${live.humidity.toInt()}%',
                                  style:
                                      GoogleFonts.poppins(fontSize: 11)),
                              const SizedBox(width: 8),
                              _S('${live.pm1_0.toInt()}', 'PM1.0'),
                            ]),
                          ] else
                            Text('No live data',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade400)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: device.isOnline
                                    ? AppTheme.primary
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              device.isOnline ? 'Online' : 'Offline',
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: device.isOnline
                                      ? AppTheme.primary
                                      : Colors.grey),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _S extends StatelessWidget {
  final String v;
  final String l;
  const _S(this.v, this.l);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600)),
        Text(l,
            style: GoogleFonts.poppins(
                fontSize: 9, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _LevelsView extends StatelessWidget {
  final AirQualityProvider aqProvider;

  const _LevelsView({required this.aqProvider});

  @override
  Widget build(BuildContext context) {
    final live = aqProvider.live;

    if (live == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('Waiting for live data...',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );
    }

    final metrics = [
      _DonutMetric(
          label: 'PM 2.5',
          value: live.pm2_5,
          max: 500,
          unit: 'μg/m³',
          color: const Color(0xFF7B1FA2)),
      _DonutMetric(
          label: 'PM 1.0',
          value: live.pm1_0,
          max: 500,
          unit: 'μg/m³',
          color: AppTheme.primary),
      _DonutMetric(
          label: 'PM 10',
          value: live.pm10,
          max: 500,
          unit: 'μg/m³',
          color: Colors.blueAccent),
      _DonutMetric(
          label: 'Temperature',
          value: live.temperature,
          max: 50,
          unit: '°C',
          color: Colors.redAccent),
      _DonutMetric(
          label: 'Gas PPM',
          value: live.gasPpm,
          max: 1000,
          unit: 'ppm',
          color: const Color(0xFFF5A623)),
      _DonutMetric(
          label: 'Humidity',
          value: live.humidity,
          max: 100,
          unit: '%',
          color: Colors.blue),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Levels',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppTheme.primary, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('Live',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.primary)),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: metrics.length,
            itemBuilder: (_, i) => _DonutCard(metric: metrics[i]),
          ),
        ],
      ),
    );
  }
}

class _DonutMetric {
  final String label;
  final double value;
  final double max;
  final String unit;
  final Color color;
  const _DonutMetric(
      {required this.label,
      required this.value,
      required this.max,
      required this.unit,
      required this.color});
}

class _DonutCard extends StatelessWidget {
  final _DonutMetric metric;
  const _DonutCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final pct = (metric.value / metric.max).clamp(0.0, 1.0);
    final remaining = 1.0 - pct;

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
                  centerSpaceRadius: 44,
                  sections: [
                    PieChartSectionData(
                        value: pct * 100,
                        color: metric.color,
                        radius: 16,
                        showTitle: false),
                    PieChartSectionData(
                        value: remaining * 100,
                        color: Colors.grey.shade200,
                        radius: 16,
                        showTitle: false),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric.value.toStringAsFixed(metric.unit == '°C' ? 1 : 0),
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(metric.unit,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(metric.label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ReportsView extends StatelessWidget {
  final AqiReport weekly;
  final AqiReport monthly;
  final VoidCallback onSave;

  const _ReportsView(
      {required this.weekly,
      required this.monthly,
      required this.onSave});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final updatedLabel =
        'Last Updated ${now.hour}:${now.minute.toString().padLeft(2, '0')}, '
        '${_month(now.month)} ${now.day}, ${now.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(updatedLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade500)),
              OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.download_outlined, size: 14),
                label:
                    Text('Save', style: GoogleFonts.poppins(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _LineReportCard(report: weekly),
          const SizedBox(height: 24),
          _LineReportCard(report: monthly),
        ],
      ),
    );
  }

  static String _month(int m) {
    const labels = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return labels[m - 1];
  }
}

class _SaveReportSheet extends StatefulWidget {
  final AqiReport weeklyReport;
  final AqiReport monthlyReport;

  const _SaveReportSheet(
      {required this.weeklyReport, required this.monthlyReport});

  @override
  State<_SaveReportSheet> createState() => _SaveReportSheetState();
}

class _SaveReportSheetState extends State<_SaveReportSheet> {
  String _selected = 'weekly';
  bool _downloading = false;
  bool _done = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _done = true;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final report =
        _selected == 'weekly' ? widget.weeklyReport : widget.monthlyReport;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Download Report',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Choose the period for your report',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PeriodOption(
                  label: 'Weekly',
                  subtitle: 'Last 7 days',
                  icon: Icons.calendar_view_week_outlined,
                  selected: _selected == 'weekly',
                  onTap: () => setState(() => _selected = 'weekly'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PeriodOption(
                  label: 'Hourly',
                  subtitle: 'Last 24h',
                  icon: Icons.calendar_month_outlined,
                  selected: _selected == 'monthly',
                  onTap: () => setState(() => _selected = 'monthly'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_chart_outlined_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.title,
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        'Peak AQI: ${report.peakAqi}  ·  ${report.points.length} data points',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _downloading || _done ? null : _download,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor:
                    AppTheme.primary.withValues(alpha: 0.7),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: _done
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Downloaded!',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                      ],
                    )
                  : _downloading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_outlined,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Download Report',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodOption(
      {required this.label,
      required this.subtitle,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE8F8F1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? AppTheme.primary
                    : Colors.grey.shade400,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.primary
                              : Colors.black87)),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineReportCard extends StatelessWidget {
  final AqiReport report;
  const _LineReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.title,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('No data available',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    final spots = report.points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final peakIdx = report.points
        .indexWhere((p) => p.value == report.peakAqi.toDouble());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report.title,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          Text(report.subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= report.points.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(report.points[i].label,
                            style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.grey.shade500));
                      },
                      reservedSize: 20,
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, i) =>
                          FlDotCirclePainter(
                        radius: i == peakIdx ? 5 : 3,
                        color: i == peakIdx
                            ? Colors.white
                            : Colors.blueAccent,
                        strokeWidth: i == peakIdx ? 2 : 0,
                        strokeColor: Colors.blueAccent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blueAccent.withValues(alpha: 0.3),
                          Colors.blueAccent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                extraLinesData: peakIdx >= 0
                    ? ExtraLinesData(verticalLines: [
                        VerticalLine(
                          x: peakIdx.toDouble(),
                          color: Colors.grey.shade300,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                          label: VerticalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            labelResolver: (_) =>
                                '${report.peakAqi} AQI',
                            style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: Colors.grey.shade600),
                          ),
                        ),
                      ])
                    : const ExtraLinesData(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
