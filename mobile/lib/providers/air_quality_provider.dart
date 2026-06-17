import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/influx_service.dart';
import '../services/mqtt_service.dart';

class _AlertThreshold {
  final String field;
  final double threshold;
  final String level;
  final String Function(String device, double value) message;

  const _AlertThreshold({
    required this.field,
    required this.threshold,
    required this.level,
    required this.message,
  });
}

class AirQualityProvider extends ChangeNotifier {
  final MqttService _mqtt;
  final InfluxService _influx;
  final Dio? _dio;

  List<InfluxPoint> _history = [];
  bool _isLoadingHistory = false;
  DateTime? _lastFetch;
  Timer? _pollTimer;

  final Map<String, DateTime> _lastAlertSent = {};
  static const _alertCooldown = Duration(minutes: 9);

  static const _thresholds = [
    _AlertThreshold(
      field: 'pm2_5',
      threshold: 55.5,
      level: 'warning',
      message: _pm25WarningMsg,
    ),
    _AlertThreshold(
      field: 'pm2_5',
      threshold: 150.5,
      level: 'critical',
      message: _pm25CriticalMsg,
    ),
    _AlertThreshold(
      field: 'gas_ppm',
      threshold: 1000.0,
      level: 'warning',
      message: _gasWarningMsg,
    ),
    _AlertThreshold(
      field: 'gas_ppm',
      threshold: 2000.0,
      level: 'critical',
      message: _gasCriticalMsg,
    ),
  ];

  static String _pm25WarningMsg(String device, double v) =>
      '$device PM 2.5 reached ${v.toStringAsFixed(1)} μg/m³.';
  static String _pm25CriticalMsg(String device, double v) =>
      '$device PM 2.5 reached ${v.toStringAsFixed(1)} μg/m³.';
  static String _gasWarningMsg(String device, double v) =>
      '$device Gas PPM reached ${v.toStringAsFixed(0)} ppm.';
  static String _gasCriticalMsg(String device, double v) =>
      '$device Gas PPM reached ${v.toStringAsFixed(0)} ppm.';

  List<InfluxPoint> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;

  AirQualityPayload? get live => _mqtt.latest;
  bool get isLiveConnected => _mqtt.isConnected;

  InfluxService get influxService => _influx;
  Dio? get apiDio => _dio;

  AirQualityProvider(this._mqtt, this._influx, {Dio? dio})
      : _dio = dio {
    _mqtt.addListener(_onMqttUpdate);
  }

  void _onMqttUpdate() {
    notifyListeners();
    _checkThresholds();
  }

  void _checkThresholds() {
    final payload = _mqtt.latest;
    if (payload == null || _dio == null) return;

    final fieldValues = {
      'pm2_5': payload.pm2_5,
      'gas_ppm': payload.gasPpm,
    };

    for (final t in _thresholds) {
      final value = fieldValues[t.field];
      if (value == null || value < t.threshold) continue;

      final key = '${payload.device}|${t.field}|${t.level}';
      final lastSent = _lastAlertSent[key];
      if (lastSent != null &&
          DateTime.now().difference(lastSent) < _alertCooldown) {
        continue;
      }

      _lastAlertSent[key] = DateTime.now();
      _postAlert(
        message: t.message(payload.device, value),
        level: t.level,
        device: payload.device,
        field: t.field,
        value: value,
        threshold: t.threshold,
      );
    }
  }

  void _postAlert({
    required String message,
    required String level,
    required String device,
    required String field,
    required double value,
    required double threshold,
  }) {
    _dio!
        .post('/api/notifications/alerts', data: {
          'message': message,
          'level': level,
          'device': device,
          'field': field,
          'value': value,
          'threshold': threshold,
        })
        .catchError((e) {
          _lastAlertSent.remove('$device|$field|$level');
          debugPrint('Alert post failed: $e');
          return e as dynamic;
        });
  }

  void startPolling() {
    _fetchHistory();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchHistory(),
    );
  }

  Future<void> _fetchHistory() async {
    _isLoadingHistory = true;
    notifyListeners();
    _history = await _influx.queryLast24Hours();
    _lastFetch = DateTime.now();
    _isLoadingHistory = false;
    notifyListeners();
  }

  Future<void> refresh() => _fetchHistory();

  List<InfluxPoint> historyForField(String field) =>
      _history.where((p) => p.field == field).toList();

  double? latestValueForField(String field) {
    final pts = historyForField(field);
    return pts.isEmpty ? null : pts.last.value;
  }

  DateTime? get lastFetch => _lastFetch;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mqtt.removeListener(_onMqttUpdate);
    super.dispose();
  }
}
