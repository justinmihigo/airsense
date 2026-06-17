import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../core/config/app_config.dart';

class AirQualityPayload {
  final String device;
  final double pm1_0;
  final double pm2_5;
  final double pm10;
  final double gasPpm;
  final double temperature;
  final double humidity;
  final double? latitude;
  final double? longitude;
  final DateTime receivedAt;

  const AirQualityPayload({
    required this.device,
    required this.pm1_0,
    required this.pm2_5,
    required this.pm10,
    required this.gasPpm,
    required this.temperature,
    required this.humidity,
    this.latitude,
    this.longitude,
    required this.receivedAt,
  });

  factory AirQualityPayload.fromJson(Map<String, dynamic> json) =>
      AirQualityPayload(
        device: json['device']?.toString() ?? 'unknown',
        pm1_0: _toDouble(json['pm1_0']),
        pm2_5: _toDouble(json['pm2_5']),
        pm10: _toDouble(json['pm10']),
        gasPpm: _toDouble(json['gas_ppm']),
        temperature: _toDouble(json['temperature']),
        humidity: _toDouble(json['humidity']),
        latitude: json['latitude'] != null ? _toDouble(json['latitude']) : null,
        longitude:
            json['longitude'] != null ? _toDouble(json['longitude']) : null,
        receivedAt: DateTime.now(),
      );

  static double _toDouble(dynamic v) =>
      v == null ? 0.0 : (v as num).toDouble();

  int get aqi => _computeAqi(pm2_5);

  static int _computeAqi(double pm25) {
    if (pm25 <= 12.0) return ((pm25 / 12.0) * 50).round();
    if (pm25 <= 35.4) return (51 + ((pm25 - 12.1) / 23.3) * 49).round();
    if (pm25 <= 55.4) return (101 + ((pm25 - 35.5) / 19.9) * 49).round();
    if (pm25 <= 150.4) return (151 + ((pm25 - 55.5) / 94.9) * 49).round();
    if (pm25 <= 250.4) return (201 + ((pm25 - 150.5) / 99.9) * 99).round();
    return (301 + ((pm25 - 250.5) / 149.9) * 199).round().clamp(301, 500);
  }
}

enum MqttConnectionStatus { disconnected, connecting, connected, error }

class MqttService extends ChangeNotifier {
  MqttServerClient? _client;
  AirQualityPayload? _latest;
  MqttConnectionStatus _connectionStatus = MqttConnectionStatus.disconnected;
  String? _connectionError;

  AirQualityPayload? get latest => _latest;
  MqttConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == MqttConnectionStatus.connected;
  String? get connectionError => _connectionError;

  Future<void> connect() async {
    if (_connectionStatus == MqttConnectionStatus.connecting ||
        _connectionStatus == MqttConnectionStatus.connected) {
      debugPrint('[MQTT] Already ${_connectionStatus.name}, skipping connect');
      return;
    }

    _setStatus(MqttConnectionStatus.connecting);

    final clientId = 'airsense_mobile_${DateTime.now().millisecondsSinceEpoch}';
    final brokerUri = Uri.parse(AppConfig.mqttUrl);
    final port = brokerUri.hasPort ? brokerUri.port : 443;

    debugPrint('[MQTT] Connecting → ${AppConfig.mqttUrl}:$port | topic: ${AppConfig.mqttTopic}');

    _client = MqttServerClient.withPort(
      AppConfig.mqttUrl,
      clientId,
      port,
    );

    _client!.useWebSocket = true;
    _client!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    _client!.keepAlivePeriod = 60;
    _client!.autoReconnect = true;
    _client!.logging(on: false);

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnect = () {
      debugPrint('[MQTT] Auto-reconnecting...');
      _setStatus(MqttConnectionStatus.connecting);
    };
    _client!.onAutoReconnected = _onConnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client!.connectionMessage = connMessage;

    _client!.updates?.listen(_onMessage);
    debugPrint('[MQTT] updates stream listener attached');

    try {
      await _client!.connect();
    } catch (e) {
      debugPrint('[MQTT] connect() threw: $e');
      _setStatus(MqttConnectionStatus.error, error: e.toString());
      _client?.disconnect();
    }
  }

  void _onConnected() {
    _client!.subscribe(AppConfig.mqttTopic, MqttQos.atLeastOnce);
    _setStatus(MqttConnectionStatus.connected);
    debugPrint('[MQTT] Connected and subscribed to ${AppConfig.mqttTopic}');
  }

  void _onDisconnected() {
    if (_connectionStatus != MqttConnectionStatus.connecting) {
      _setStatus(MqttConnectionStatus.disconnected);
    }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    try {
      final msg = messages[0].payload as MqttPublishMessage;
      final raw = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _latest = AirQualityPayload.fromJson(json);
      notifyListeners();
    } catch (e) {
      debugPrint('[MQTT] Parse error: $e');
    }
  }

  void _setStatus(MqttConnectionStatus status, {String? error}) {
    _connectionStatus = status;
    _connectionError = error;
    notifyListeners();
  }

  void disconnect() {
    _client?.disconnect();
    _setStatus(MqttConnectionStatus.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
