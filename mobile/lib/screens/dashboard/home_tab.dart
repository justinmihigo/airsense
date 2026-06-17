import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../providers/air_quality_provider.dart';
import '../../services/influx_service.dart';
import '../../services/mqtt_service.dart';
import '../../theme/app_theme.dart';

class _MetricConfig {
  final String label;
  final String field;
  final double Function(AirQualityPayload) mqttValue;
  final String unit;
  final Color color;
  final IconData icon;

  const _MetricConfig({
    required this.label,
    required this.field,
    required this.mqttValue,
    required this.unit,
    required this.color,
    required this.icon,
  });
}

const _metrics = [
  _MetricConfig(
    label: 'Temperature',
    field: 'temperature',
    mqttValue: _tempValue,
    unit: '°C',
    color: Color(0xFFF97316),
    icon: Icons.thermostat_outlined,
  ),
  _MetricConfig(
    label: 'Humidity',
    field: 'humidity',
    mqttValue: _humidValue,
    unit: '%',
    color: Color(0xFF3B82F6),
    icon: Icons.water_drop_outlined,
  ),
  _MetricConfig(
    label: 'Gas PPM',
    field: 'gas_ppm',
    mqttValue: _gasValue,
    unit: 'ppm',
    color: Color(0xFF8B5CF6),
    icon: Icons.air_outlined,
  ),
  _MetricConfig(
    label: 'PM 1.0',
    field: 'pm1_0',
    mqttValue: _pm10Value,
    unit: 'µg/m³',
    color: Color(0xFF22C55E),
    icon: Icons.grain_outlined,
  ),
  _MetricConfig(
    label: 'PM 2.5',
    field: 'pm2_5',
    mqttValue: _pm25Value,
    unit: 'µg/m³',
    color: Color(0xFFEAB308),
    icon: Icons.blur_on_outlined,
  ),
  _MetricConfig(
    label: 'PM 10',
    field: 'pm10',
    mqttValue: _pm10mValue,
    unit: 'µg/m³',
    color: Color(0xFFEF4444),
    icon: Icons.cloud_outlined,
  ),
];

double _tempValue(AirQualityPayload p) => p.temperature;
double _humidValue(AirQualityPayload p) => p.humidity;
double _gasValue(AirQualityPayload p) => p.gasPpm;
double _pm10Value(AirQualityPayload p) => p.pm1_0;
double _pm25Value(AirQualityPayload p) => p.pm2_5;
double _pm10mValue(AirQualityPayload p) => p.pm10;

class _Alert {
  final String title;
  final String message;
  final bool isCritical;
  final DateTime time;

  const _Alert({
    required this.title,
    required this.message,
    required this.isCritical,
    required this.time,
  });
}

List<_Alert> _buildAlerts(List<InfluxPoint> history) {
  const thresholds = {
    'temperature': (warning: 35.0, critical: 40.0, lowerIsWorse: false),
    'humidity':    (warning: 35.0, critical: 20.0, lowerIsWorse: true),
    'gas_ppm':     (warning: 500.0, critical: 800.0, lowerIsWorse: false),
    'pm1_0':       (warning: 15.0, critical: 35.0, lowerIsWorse: false),
    'pm2_5':       (warning: 35.0, critical: 55.0, lowerIsWorse: false),
    'pm10':        (warning: 50.0, critical: 100.0, lowerIsWorse: false),
  };

  const fieldLabels = {
    'temperature': 'Temperature',
    'humidity':    'Humidity',
    'gas_ppm':     'Gas PPM',
    'pm1_0':       'PM 1.0',
    'pm2_5':       'PM 2.5',
    'pm10':        'PM 10',
  };

  const fieldUnits = {
    'temperature': '°C',
    'humidity':    '%',
    'gas_ppm':     'ppm',
    'pm1_0':       'µg/m³',
    'pm2_5':       'µg/m³',
    'pm10':        'µg/m³',
  };

  final alerts = <_Alert>[];

  for (final pt in history) {
    final t = thresholds[pt.field];
    if (t == null) continue;

    final isCritical = t.lowerIsWorse
        ? pt.value <= t.critical
        : pt.value >= t.critical;
    final isWarning = t.lowerIsWorse
        ? pt.value <= t.warning
        : pt.value >= t.warning;

    if (!isCritical && !isWarning) continue;

    final label = fieldLabels[pt.field]!;
    final unit  = fieldUnits[pt.field]!;
    final descriptor = t.lowerIsWorse ? 'dropped to' : 'reached';

    alerts.add(_Alert(
      title: isCritical ? 'Critical alert' : 'Alert',
      message:
          '${pt.device} $label $descriptor ${pt.value.toStringAsFixed(1)} $unit.',
      isCritical: isCritical,
      time: pt.time,
    ));
  }

  alerts.sort((a, b) => b.time.compareTo(a.time));
  return alerts.take(10).toList();
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AirQualityProvider, AuthProvider>(
      builder: (context, aq, auth, _) {
        final live = aq.live;
        final greeting = auth.user != null
            ? 'Welcome back, ${auth.user!.name.split(' ').first}'
            : 'Dashboard';

        return Scaffold(
          backgroundColor: const Color(0xFFF6F6FA),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _Header(
                      greeting: greeting,
                      aq: aq,
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _MetricCard(
                        config: _metrics[i],
                        live: live,
                        influxLatest: aq.latestValueForField(
                            _metrics[i].field),
                        isLoading: aq.isLoadingHistory && live == null,
                      ),
                      childCount: _metrics.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _ChartsSection(aq: aq),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _AlertsSection(
                      alerts: _buildAlerts(aq.history),
                      isLoading: aq.isLoadingHistory && aq.history.isEmpty,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String greeting;
  final AirQualityProvider aq;

  const _Header({required this.greeting, required this.aq});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    greeting,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Consumer<MqttService>(
          builder: (_, mqtt, __) => Wrap(
            spacing: 8,
            children: [
              _StatusBadge(
                label: mqtt.isConnected ? 'MQTT Live' : 'MQTT Offline',
                isActive: mqtt.isConnected,
                activeColor: const Color(0xFF16A34A),
                activeBg: const Color(0xFFDCFCE7),
                inactiveBg: const Color(0xFFF3F4F6),
              ),
              _StatusBadge(
                label: aq.isLoadingHistory
                    ? 'Syncing…'
                    : aq.lastFetch != null
                        ? 'InfluxDB OK'
                        : 'InfluxDB',
                isActive: aq.lastFetch != null && !aq.isLoadingHistory,
                activeColor: const Color(0xFF1D4ED8),
                activeBg: const Color(0xFFDBEAFE),
                inactiveBg: const Color(0xFFF3F4F6),
              ),
              if (aq.lastFetch != null && !aq.isLoadingHistory)
                _StatusBadge(
                  label:
                      '${aq.lastFetch!.hour.toString().padLeft(2, '0')}:${aq.lastFetch!.minute.toString().padLeft(2, '0')}',
                  isActive: false,
                  activeColor: Colors.grey,
                  activeBg: const Color(0xFFF3F4F6),
                  inactiveBg: const Color(0xFFF3F4F6),
                  icon: Icons.refresh_outlined,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color activeBg;
  final Color inactiveBg;
  final IconData? icon;

  const _StatusBadge({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.activeBg,
    required this.inactiveBg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? activeBg : inactiveBg;
    final fg = isActive ? activeColor : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? activeColor : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricConfig config;
  final AirQualityPayload? live;
  final double? influxLatest;
  final bool isLoading;

  const _MetricCard({
    required this.config,
    required this.live,
    required this.influxLatest,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final value = live != null
        ? config.mqttValue(live!)
        : influxLatest;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  config.label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(config.icon, size: 14, color: config.color),
            ],
          ),
          const Spacer(),
          if (isLoading && value == null)
            Container(
              height: 20,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(4),
              ),
            )
          else if (value != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    TextSpan(
                      text: ' ${config.unit}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              '--',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: const Color(0xFF9CA3AF),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartsSection extends StatelessWidget {
  final AirQualityProvider aq;

  const _ChartsSection({required this.aq});

  static const _chartFields = [
    ('temperature', 'Temperature', '°C', Color(0xFF22C55E)),
    ('humidity', 'Humidity', '%', Color(0xFF3B82F6)),
    ('pm2_5', 'PM 2.5', 'µg/m³', Color(0xFFF59E0B)),
    ('gas_ppm', 'Gas PPM', 'ppm', Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _chartFields.map((cfg) {
        final field = cfg.$1;
        final title = cfg.$2;
        final unit = cfg.$3;
        final color = cfg.$4;

        final points = aq.historyForField(field)
          ..sort((a, b) => a.time.compareTo(b.time));
        final latest = points.isEmpty ? null : points.last.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'Last 24h ($unit)',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  if (latest != null)
                    Text(
                      '${latest.toStringAsFixed(1)} $unit',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: aq.isLoadingHistory && points.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : points.isEmpty
                        ? Center(
                            child: Text(
                              'No data — check InfluxDB',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          )
                        : _Sparkline(points: points, color: color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<InfluxPoint> points;
  final Color color;

  const _Sparkline({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(points: points, color: color),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<InfluxPoint> points;
  final Color color;

  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final values = points.map((p) => p.value).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs();
    final effectiveRange = range < 0.001 ? 1.0 : range;

    double xOf(int i) => i / (points.length - 1) * size.width;
    double yOf(double v) =>
        size.height - ((v - minVal) / effectiveRange) * (size.height * 0.85) -
        size.height * 0.075;

    final fillPath = Path();
    fillPath.moveTo(xOf(0), size.height);
    for (int i = 0; i < points.length; i++) {
      fillPath.lineTo(xOf(i), yOf(values[i]));
    }
    fillPath.lineTo(xOf(points.length - 1), size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    final linePath = Path();
    linePath.moveTo(xOf(0), yOf(values[0]));
    for (int i = 1; i < points.length; i++) {
      final x0 = xOf(i - 1);
      final y0 = yOf(values[i - 1]);
      final x1 = xOf(i);
      final y1 = yOf(values[i]);
      final cpx = (x0 + x1) / 2;
      linePath.cubicTo(cpx, y0, cpx, y1, x1, y1);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}

class _AlertsSection extends StatelessWidget {
  final List<_Alert> alerts;
  final bool isLoading;

  const _AlertsSection({required this.alerts, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Text(
                    'Sensor Alerts',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              Text(
                '${alerts.length} active',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            Container(
              height: 36,
              width: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
            )
          else if (alerts.isEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Text(
                    'All readings within normal range',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: alerts
                  .map((a) => _AlertTile(alert: a))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final _Alert alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final bgColor = alert.isCritical
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFFFFBEB);
    final borderColor = alert.isCritical
        ? const Color(0xFFFECACA)
        : const Color(0xFFFDE68A);
    final iconColor = alert.isCritical
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);
    final titleColor = alert.isCritical
        ? const Color(0xFFB91C1C)
        : const Color(0xFFB45309);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                Text(
                  alert.message,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
