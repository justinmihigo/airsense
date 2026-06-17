import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/air_quality_provider.dart';
import '../../services/influx_service.dart';
import '../../theme/app_theme.dart';

class _FieldStats {
  final int count;
  final double mean;
  final double min;
  final double max;

  const _FieldStats({
    required this.count,
    required this.mean,
    required this.min,
    required this.max,
  });
}

class _MLRecommendation {
  final int? aqi;
  final String level;
  final String color;
  final List<String> healthAdvice;
  final List<String> activityAdvice;
  final List<String> ventilationAdvice;
  final List<String> sensorAlerts;

  const _MLRecommendation({
    required this.aqi,
    required this.level,
    required this.color,
    required this.healthAdvice,
    required this.activityAdvice,
    required this.ventilationAdvice,
    required this.sensorAlerts,
  });

  factory _MLRecommendation.fromJson(Map<String, dynamic> j) =>
      _MLRecommendation(
        aqi: j['aqi'] != null ? (j['aqi'] as num).round() : null,
        level: j['level']?.toString() ?? 'Unknown',
        color: j['color']?.toString() ?? '#9CA3AF',
        healthAdvice: _toStrList(j['health_advice']),
        activityAdvice: _toStrList(j['activity_advice']),
        ventilationAdvice: _toStrList(j['ventilation_advice']),
        sensorAlerts: _toStrList(j['sensor_alerts']),
      );

  static List<String> _toStrList(dynamic v) =>
      v == null ? [] : (v as List).map((e) => e.toString()).toList();
}

class _ForecastPoint {
  final double mean;
  final double lowerCi;
  final double upperCi;

  const _ForecastPoint(
      {required this.mean, required this.lowerCi, required this.upperCi});

  factory _ForecastPoint.fromJson(Map<String, dynamic> j) => _ForecastPoint(
        mean: (j['mean'] as num).toDouble(),
        lowerCi: (j['lower_ci'] as num).toDouble(),
        upperCi: (j['upper_ci'] as num).toDouble(),
      );
}

class _ForecastResult {
  final int steps;
  final String unit;
  final List<_ForecastPoint> forecast;
  final int historyUsed;
  final double? lastObserved;

  const _ForecastResult({
    required this.steps,
    required this.unit,
    required this.forecast,
    required this.historyUsed,
    this.lastObserved,
  });

  factory _ForecastResult.fromJson(Map<String, dynamic> j) => _ForecastResult(
        steps: (j['steps'] as num).toInt(),
        unit: j['unit']?.toString() ?? 'µg/m³',
        forecast: (j['forecast'] as List)
            .map((e) => _ForecastPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        historyUsed: (j['history_used'] as num?)?.toInt() ?? 0,
        lastObserved: j['last_observed'] != null
            ? (j['last_observed'] as num).toDouble()
            : null,
      );
}

class _FieldConfig {
  final String title;
  final String unit;
  final Color color;

  const _FieldConfig(
      {required this.title, required this.unit, required this.color});
}

const _fields = [
  'temperature',
  'humidity',
  'gas_ppm',
  'pm1_0',
  'pm2_5',
  'pm10',
];

const _fieldConfig = {
  'temperature': _FieldConfig(
      title: 'Temperature', unit: '°C', color: Color(0xFF22C55E)),
  'humidity':
      _FieldConfig(title: 'Humidity', unit: '%', color: Color(0xFF3B82F6)),
  'gas_ppm':
      _FieldConfig(title: 'Gas PPM', unit: 'ppm', color: Color(0xFF8B5CF6)),
  'pm1_0':
      _FieldConfig(title: 'PM 1.0', unit: 'µg/m³', color: Color(0xFFF97316)),
  'pm2_5':
      _FieldConfig(title: 'PM 2.5', unit: 'µg/m³', color: Color(0xFFF59E0B)),
  'pm10':
      _FieldConfig(title: 'PM 10', unit: 'µg/m³', color: Color(0xFFEF4444)),
};

const _ranges = [
  ('-1h', '1h', 'Last hour'),
  ('-24h', '24h', 'Last 24 hours'),
  ('-7d', '7d', 'Last 7 days'),
  ('-30d', '30d', 'Last 30 days'),
];

Map<String, Color> _aqiBgColor = {
  'Good': const Color(0xFFF0FDF4),
  'Moderate': const Color(0xFFFFFBEB),
  'Unhealthy for Sensitive Groups': const Color(0xFFFFF7ED),
  'Unhealthy': const Color(0xFFFEF2F2),
  'Very Unhealthy': const Color(0xFFFAF5FF),
  'Hazardous': const Color(0xFFFFF1F2),
  'Unknown': const Color(0xFFF9FAFB),
};

Map<String, Color> _aqiTextColor = {
  'Good': const Color(0xFF15803D),
  'Moderate': const Color(0xFFB45309),
  'Unhealthy for Sensitive Groups': const Color(0xFFC2410C),
  'Unhealthy': const Color(0xFFB91C1C),
  'Very Unhealthy': const Color(0xFF7E22CE),
  'Hazardous': const Color(0xFF9F1239),
  'Unknown': const Color(0xFF6B7280),
};

Map<String, Color> _aqiDotColor = {
  'Good': const Color(0xFF22C55E),
  'Moderate': const Color(0xFFEAB308),
  'Unhealthy for Sensitive Groups': const Color(0xFFF97316),
  'Unhealthy': const Color(0xFFEF4444),
  'Very Unhealthy': const Color(0xFFA855F7),
  'Hazardous': const Color(0xFFE11D48),
  'Unknown': const Color(0xFF9CA3AF),
};

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  String _lookback = '-24h';
  bool _insightsOpen = true;

  _MLRecommendation? _recommendation;
  _ForecastResult? _forecast;
  bool _mlLoading = false;
  String? _mlError;

  List<InfluxPoint> _rangeHistory = [];
  bool _rangeLoading = false;
  DateTime? _lastUpdated;
  Timer? _refreshTimer;

  Duration get _refreshInterval {
    switch (_lookback) {
      case '-1h':
        return const Duration(seconds: 15);
      case '-24h':
        return const Duration(seconds: 30);
      default:
        return const Duration(seconds: 60);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRange();
      _startTimer();
    });
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _fetchRange());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRange() async {
    final influx = context.read<AirQualityProvider>().influxService;

    setState(() => _rangeLoading = true);

    final pts = await influx.queryRange(range: _lookback);
    if (!mounted) return;
    setState(() {
      _rangeHistory = pts;
      _rangeLoading = false;
      _lastUpdated = DateTime.now();
    });

    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    final aq = context.read<AirQualityProvider>();
    final dio = aq.apiDio;
    if (dio == null) return;

    setState(() {
      _mlLoading = true;
      _mlError = null;
    });

    final stats = _computeStats();
    double? statMean(String field) => stats[field]?.mean;

    final body = {
      'pm25': statMean('pm2_5'),
      'pm10': statMean('pm10'),
      'co2': statMean('gas_ppm'),
      'temperature': statMean('temperature'),
      'humidity': statMean('humidity'),
      'occupancy': 1,
    };

    final pm25Points = _rangeHistory
        .where((p) => p.field == 'pm2_5')
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final history = pm25Points.map((p) => p.value).toList();

    try {
      _MLRecommendation? rec;
      _ForecastResult? fc;

      await Future.wait([
        dio.post('/api/ml/recommend', data: body).then((r) {
          rec = _MLRecommendation.fromJson(r.data as Map<String, dynamic>);
        }).catchError((_) {}),
        dio.post('/api/ml/forecast', data: {'history': history, 'steps': 48})
            .then((r) {
          fc = _ForecastResult.fromJson(r.data as Map<String, dynamic>);
        }).catchError((_) {}),
      ]);

      if (!mounted) return;
      setState(() {
        _recommendation = rec;
        _forecast = fc;
        _mlLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mlError = e.toString().contains('503') ||
                e.toString().contains('Network')
            ? 'ML service is offline.'
            : 'ML service unreachable.';
        _mlLoading = false;
      });
    }
  }

  Map<String, _FieldStats> _computeStats() {
    final out = <String, _FieldStats>{};
    for (final field in _fields) {
      final vals = _rangeHistory
          .where((p) => p.field == field)
          .map((p) => p.value)
          .toList();
      if (vals.isEmpty) continue;
      double sum = 0, min = vals[0], max = vals[0];
      for (final v in vals) {
        sum += v;
        if (v < min) min = v;
        if (v > max) max = v;
      }
      out[field] = _FieldStats(
        count: vals.length,
        mean: sum / vals.length,
        min: min,
        max: max,
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _computeStats();
    final rangeLabel =
        _ranges.firstWhere((r) => r.$1 == _lookback).$3;

    final aq = context.watch<AirQualityProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _AnalyticsHeader(
                  rangeLabel: rangeLabel,
                  lookback: _lookback,
                  isLoading: _rangeLoading,
                  lastUpdated: _lastUpdated,
                  onRangeChanged: (v) {
                    setState(() => _lookback = v);
                    _fetchRange();
                    _startTimer(); // restart with new interval for this range
                  },
                  onRefresh: _fetchRange,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _NowChips(aq: aq, isLoading: _rangeLoading),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _PeriodStats(
                  stats: stats,
                  rangeLabel: rangeLabel,
                  totalRecords: _rangeHistory.length,
                  isLoading: _rangeLoading,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _InsightsPanel(
                  recommendation: _recommendation,
                  forecast: _forecast,
                  mlLoading: _mlLoading,
                  mlError: _mlError,
                  isOpen: _insightsOpen,
                  pm25History: _rangeHistory
                      .where((p) => p.field == 'pm2_5')
                      .map((p) => p.value)
                      .toList(),
                  onToggle: () =>
                      setState(() => _insightsOpen = !_insightsOpen),
                  onRefresh: _fetchInsights,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _TrendCharts(
                  history: _rangeHistory,
                  rangeLabel: rangeLabel,
                  isLoading: _rangeLoading,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  final String rangeLabel;
  final String lookback;
  final bool isLoading;
  final DateTime? lastUpdated;
  final ValueChanged<String> onRangeChanged;
  final VoidCallback onRefresh;

  const _AnalyticsHeader({
    required this.rangeLabel,
    required this.lookback,
    required this.isLoading,
    required this.lastUpdated,
    required this.onRangeChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 20, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              'Analytics',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_outlined,
                      size: 11, color: Color(0xFF6B7280)),
                  const SizedBox(width: 3),
                  Text(
                    rangeLabel,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: const Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (isLoading)
              Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 6),
                  Text('Syncing…',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey.shade400)),
                ],
              )
            else if (lastUpdated != null)
              GestureDetector(
                onTap: onRefresh,
                child: Row(
                  children: [
                    const Icon(Icons.refresh_outlined,
                        size: 13, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 3),
                    Text(
                      '${lastUpdated!.hour.toString().padLeft(2, '0')}:${lastUpdated!.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: const Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: _ranges.map((r) {
              final active = lookback == r.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onRangeChanged(r.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? AppTheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        r.$2,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _NowChips extends StatelessWidget {
  final AirQualityProvider aq;
  final bool isLoading;

  const _NowChips({required this.aq, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "Now" badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Now',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF15803D),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ..._fields.map((field) {
            final cfg = _fieldConfig[field]!;
            final val = aq.latestValueForField(field);
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cfg.color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cfg.title,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isLoading
                        ? '…'
                        : val != null
                            ? '${val.toStringAsFixed(1)} ${cfg.unit}'
                            : '--',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cfg.color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PeriodStats extends StatelessWidget {
  final Map<String, _FieldStats> stats;
  final String rangeLabel;
  final int totalRecords;
  final bool isLoading;

  const _PeriodStats({
    required this.stats,
    required this.rangeLabel,
    required this.totalRecords,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  const Icon(Icons.storage_outlined,
                      size: 16, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Text(
                    'Period statistics — $rangeLabel',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              Text(
                '${totalRecords.toString()} readings',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: const Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = (constraints.maxWidth - 10) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _fields.map((field) {
                  final cfg = _fieldConfig[field]!;
                  final s = stats[field];
                  return SizedBox(
                    width: cellWidth,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cfg.color,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  cfg.title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF4B5563),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (isLoading && s == null)
                            Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          else if (s != null) ...[
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: s.mean.toStringAsFixed(1),
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: cfg.color,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' ${cfg.unit}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 8,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              '${s.min.toStringAsFixed(1)} – ${s.max.toStringAsFixed(1)}',
                              style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: const Color(0xFF6B7280)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'n = ${s.count}',
                              style: GoogleFonts.poppins(
                                  fontSize: 7,
                                  color: const Color(0xFF9CA3AF)),
                            ),
                          ] else
                            Text(
                              '--',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF9CA3AF)),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  final _MLRecommendation? recommendation;
  final _ForecastResult? forecast;
  final bool mlLoading;
  final String? mlError;
  final bool isOpen;
  final List<double> pm25History;
  final VoidCallback onToggle;
  final VoidCallback onRefresh;

  const _InsightsPanel({
    required this.recommendation,
    required this.forecast,
    required this.mlLoading,
    required this.mlError,
    required this.isOpen,
    required this.pm25History,
    required this.onToggle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final level = recommendation?.level ?? 'Unknown';
    final bgColor = _aqiBgColor[level] ?? _aqiBgColor['Unknown']!;
    final textColor = _aqiTextColor[level] ?? _aqiTextColor['Unknown']!;
    final dotColor = _aqiDotColor[level] ?? _aqiDotColor['Unknown']!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                border: isOpen
                    ? const Border(
                        bottom: BorderSide(color: Color(0xFFF3F4F6)))
                    : null,
                borderRadius: isOpen
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_outlined,
                      size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    'AI Insights',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ML-powered',
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4F46E5)),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onRefresh,
                    child: mlLoading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.grey.shade400),
                          )
                        : const Icon(Icons.refresh_outlined,
                            size: 16, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),

          if (isOpen)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mlError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mlError!,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (mlLoading && recommendation == null) ...[
                    _Skeleton(height: 80),
                    const SizedBox(height: 10),
                    _Skeleton(height: 60),
                    const SizedBox(height: 10),
                    _Skeleton(height: 100),
                  ],

                  if (recommendation != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: dotColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Column(
                            children: [
                              Text(
                                recommendation!.aqi != null
                                    ? '${recommendation!.aqi}'
                                    : '--',
                                style: GoogleFonts.poppins(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'AQI',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF9CA3AF),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: dotColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        recommendation!.level,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    ('Good', const Color(0xFF22C55E)),
                                    ('Moderate', const Color(0xFFEAB308)),
                                    ('USG', const Color(0xFFF97316)),
                                    ('Unhealthy', const Color(0xFFEF4444)),
                                    ('V.Unhealthy', const Color(0xFFA855F7)),
                                    ('Hazardous', const Color(0xFFE11D48)),
                                  ].map((e) => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: e.$2,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(e.$1,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 8,
                                                  color: const Color(
                                                      0xFF9CA3AF))),
                                        ],
                                      )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (recommendation!.sensorAlerts.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...recommendation!.sensorAlerts.map((a) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_rounded,
                                    size: 13, color: Color(0xFFEF4444)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(a,
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color:
                                              const Color(0xFFB91C1C))),
                                ),
                              ],
                            ),
                          )),
                    ],

                    const SizedBox(height: 12),
                    _AdviceCard(
                      icon: Icons.favorite_outline_rounded,
                      label: 'Health',
                      advice: recommendation!.healthAdvice,
                      bgColor: const Color(0xFFFFF1F2),
                      borderColor: const Color(0xFFFECDD3),
                      iconColor: const Color(0xFFF43F5E),
                      labelColor: const Color(0xFFBE123C),
                    ),
                    const SizedBox(height: 8),
                    _AdviceCard(
                      icon: Icons.directions_run_rounded,
                      label: 'Activity',
                      advice: recommendation!.activityAdvice,
                      bgColor: const Color(0xFFEFF6FF),
                      borderColor: const Color(0xFFBFDBFE),
                      iconColor: const Color(0xFF3B82F6),
                      labelColor: const Color(0xFF1D4ED8),
                    ),
                    const SizedBox(height: 8),
                    _AdviceCard(
                      icon: Icons.window_outlined,
                      label: 'Ventilation',
                      advice: recommendation!.ventilationAdvice,
                      bgColor: const Color(0xFFF0FDFA),
                      borderColor: const Color(0xFF99F6E4),
                      iconColor: const Color(0xFF14B8A6),
                      labelColor: const Color(0xFF0F766E),
                    ),

                    if (forecast != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.trending_up_rounded,
                              size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'PM 2.5 Forecast — next ${forecast!.steps} steps',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SARIMA · 95% CI',
                              style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: const Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                      if (forecast!.historyUsed > 0 ||
                          forecast!.lastObserved != null) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (forecast!.historyUsed > 0)
                              _Tag(
                                  'fit on ${forecast!.historyUsed} readings'),
                            if (forecast!.lastObserved != null)
                              _Tag(
                                  'last obs: ${forecast!.lastObserved!.toStringAsFixed(1)} ${forecast!.unit}'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 120,
                        child: _ForecastChart(
                          points: forecast!.forecast,
                          history: pm25History,
                          unit: forecast!.unit,
                        ),
                      ),
                    ] else if (pm25History.length < 10) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'Need at least 10 PM2.5 readings to forecast (have ${pm25History.length}). Increase the time range.',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ],

                  if (recommendation == null && !mlLoading && mlError == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Tap refresh to run the ML analysis.',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF9CA3AF)),
                        ),
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

class _AdviceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> advice;
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final Color labelColor;

  const _AdviceCard({
    required this.icon,
    required this.label,
    required this.advice,
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...advice.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  a,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF374151),
                      height: 1.5),
                ),
              )),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 9, color: const Color(0xFF4B5563)),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _ForecastChart extends StatelessWidget {
  final List<_ForecastPoint> points;
  final List<double> history;
  final String unit;

  const _ForecastChart({
    required this.points,
    required this.history,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ForecastPainter(points: points, history: history),
      size: Size.infinite,
    );
  }
}

class _ForecastPainter extends CustomPainter {
  final List<_ForecastPoint> points;
  final List<double> history;

  _ForecastPainter({required this.points, required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final tail = history.length > points.length
        ? history.sublist(history.length - points.length)
        : history;
    final tailLen = tail.length;
    final totalLen = tailLen + points.length;

    final allVals = [
      ...tail,
      ...points.map((p) => p.mean),
      ...points.map((p) => p.upperCi),
      ...points.map((p) => p.lowerCi),
    ];
    final minVal = allVals.reduce((a, b) => a < b ? a : b);
    final maxVal = allVals.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).abs();
    final eff = range < 0.001 ? 1.0 : range;

    double xOf(int i) => i / (totalLen - 1) * size.width;
    double yOf(double v) =>
        size.height -
        ((v - minVal) / eff) * (size.height * 0.85) -
        size.height * 0.075;

    if (points.length > 1) {
      final ciPath = Path();
      ciPath.moveTo(xOf(tailLen), yOf(points[0].upperCi));
      for (int i = 1; i < points.length; i++) {
        ciPath.lineTo(xOf(tailLen + i), yOf(points[i].upperCi));
      }
      for (int i = points.length - 1; i >= 0; i--) {
        ciPath.lineTo(xOf(tailLen + i), yOf(points[i].lowerCi));
      }
      ciPath.close();
      canvas.drawPath(
          ciPath,
          Paint()
            ..color = const Color(0xFFF59E0B).withValues(alpha: 0.18)
            ..style = PaintingStyle.fill);
    }

    if (tail.length > 1) {
      final hPath = Path();
      hPath.moveTo(xOf(0), yOf(tail[0]));
      for (int i = 1; i < tail.length; i++) {
        final x0 = xOf(i - 1);
        final y0 = yOf(tail[i - 1]);
        final x1 = xOf(i);
        final y1 = yOf(tail[i]);
        hPath.cubicTo((x0 + x1) / 2, y0, (x0 + x1) / 2, y1, x1, y1);
      }
      canvas.drawPath(
          hPath,
          Paint()
            ..color = const Color(0xFF9CA3AF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round);
    }

    if (points.length > 1) {
      final fPath = Path();
      final startY = tail.isNotEmpty ? yOf(tail.last) : yOf(points[0].mean);
      fPath.moveTo(xOf(tailLen - 1), startY);
      for (int i = 0; i < points.length; i++) {
        final x0 = xOf(tailLen + i - 1);
        final y0 = i == 0 ? startY : yOf(points[i - 1].mean);
        final x1 = xOf(tailLen + i);
        final y1 = yOf(points[i].mean);
        fPath.cubicTo((x0 + x1) / 2, y0, (x0 + x1) / 2, y1, x1, y1);
      }
      canvas.drawPath(
          fPath,
          Paint()
            ..color = const Color(0xFFF59E0B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round);
    }

    if (tailLen > 0 && tailLen < totalLen) {
      final nowX = xOf(tailLen - 1);
      canvas.drawLine(
        Offset(nowX, 0),
        Offset(nowX, size.height),
        Paint()
          ..color = const Color(0xFF9CA3AF)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ForecastPainter old) =>
      old.points != points || old.history != history;
}

class _TrendCharts extends StatelessWidget {
  final List<InfluxPoint> history;
  final String rangeLabel;
  final bool isLoading;

  const _TrendCharts({
    required this.history,
    required this.rangeLabel,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _fields.map((field) {
        final cfg = _fieldConfig[field]!;
        final pts = history.where((p) => p.field == field).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
        final latest = pts.isEmpty ? null : pts.last.value;

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
                        cfg.title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        '$rangeLabel (${cfg.unit})',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  if (latest != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cfg.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${latest.toStringAsFixed(1)} ${cfg.unit}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cfg.color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: isLoading && pts.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : pts.isEmpty
                        ? Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bar_chart,
                                    size: 16,
                                    color: Colors.grey.shade300),
                                const SizedBox(width: 6),
                                Text(
                                  'No data — check InfluxDB',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _TrendSparkline(pts: pts, color: cfg.color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TrendSparkline extends StatelessWidget {
  final List<InfluxPoint> pts;
  final Color color;

  const _TrendSparkline({required this.pts, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendPainter(pts: pts, color: color),
      size: Size.infinite,
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<InfluxPoint> pts;
  final Color color;

  _TrendPainter({required this.pts, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final vals = pts.map((p) => p.value).toList();
    final minVal = vals.reduce((a, b) => a < b ? a : b);
    final maxVal = vals.reduce((a, b) => a > b ? a : b);
    final eff = (maxVal - minVal).abs() < 0.001 ? 1.0 : maxVal - minVal;

    double xOf(int i) => i / (pts.length - 1) * size.width;
    double yOf(double v) =>
        size.height -
        ((v - minVal) / eff) * (size.height * 0.85) -
        size.height * 0.075;

    final fill = Path()..moveTo(xOf(0), size.height);
    for (int i = 0; i < pts.length; i++) {
      fill.lineTo(xOf(i), yOf(vals[i]));
    }
    fill
      ..lineTo(xOf(pts.length - 1), size.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..color = color.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill);

    final line = Path()..moveTo(xOf(0), yOf(vals[0]));
    for (int i = 1; i < pts.length; i++) {
      final x0 = xOf(i - 1), y0 = yOf(vals[i - 1]);
      final x1 = xOf(i), y1 = yOf(vals[i]);
      line.cubicTo((x0 + x1) / 2, y0, (x0 + x1) / 2, y1, x1, y1);
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    final lastX = xOf(pts.length - 1);
    final lastY = yOf(vals.last);
    canvas.drawCircle(
        Offset(lastX, lastY),
        3.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(lastX, lastY),
        3.5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.pts != pts || old.color != color;
}
