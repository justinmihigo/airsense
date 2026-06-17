import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';

class InfluxPoint {
  final DateTime time;
  final String field;
  final double value;
  final String device;

  const InfluxPoint({
    required this.time,
    required this.field,
    required this.value,
    required this.device,
  });
}

class InfluxService {
  late final Dio _dio;

  InfluxService(Dio _) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 10),
    ));
  }

  Future<List<InfluxPoint>> queryLast24Hours({String? deviceId}) async {
    final query = _buildQuery(range: '-24h', deviceId: deviceId);
    return _execute(query);
  }

  Future<List<InfluxPoint>> queryRange({
    required String range,
    String? deviceId,
  }) async {
    final query = _buildQuery(range: range, deviceId: deviceId);
    return _execute(query);
  }

  String _buildQuery({required String range, String? deviceId}) {
    final deviceFilter = deviceId != null
        ? '|> filter(fn: (r) => r.device == "$deviceId")'
        : '';
    return '''
from(bucket: "${AppConfig.influxBucket}")
  |> range(start: $range)
  |> filter(fn: (r) => r._measurement == "${AppConfig.influxMeasurement}")
  |> filter(fn: (r) =>
      r._field == "temperature" or
      r._field == "humidity" or
      r._field == "gas_ppm" or
      r._field == "pm1_0" or
      r._field == "pm2_5" or
      r._field == "pm10")
  $deviceFilter
  |> keep(columns: ["_time", "_field", "_value", "device"])
  |> sort(columns: ["_time"])
''';
  }

  Future<List<InfluxPoint>> _execute(String fluxQuery) async {
    final url =
        '${AppConfig.influxUrl}/api/v2/query?org=${AppConfig.influxOrg}';

    debugPrint('[Influx] ── REQUEST ──────────────────────────────────');
    debugPrint('[Influx] URL    : $url');
    debugPrint('[Influx] Bucket : ${AppConfig.influxBucket}');
    debugPrint('[Influx] Org    : ${AppConfig.influxOrg}');
    debugPrint('[Influx] Measurement: ${AppConfig.influxMeasurement}');
    debugPrint('[Influx] Token  : ${AppConfig.influxToken.substring(0, 10)}…');
    debugPrint('[Influx] Query  :\n$fluxQuery');

    try {
      final res = await _dio.post(
        url,
        data: fluxQuery,
        options: Options(
          headers: {
            'Authorization': 'Token ${AppConfig.influxToken}',
            'Content-Type': 'application/vnd.flux',
            'Accept': 'application/csv',
          },
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint('[Influx] ── RESPONSE ─────────────────────────────────');
      debugPrint('[Influx] Status : ${res.statusCode}');
      final body = res.data?.toString() ?? '';
      debugPrint('[Influx] Body (first 500 chars): ${body.substring(0, body.length.clamp(0, 500))}');

      final points = _parseCsv(body);
      debugPrint('[Influx] Parsed : ${points.length} points');
      return points;
    } on DioException catch (e) {
      debugPrint('[Influx] ── ERROR ────────────────────────────────────');
      debugPrint('[Influx] Type    : ${e.type}');
      debugPrint('[Influx] Message : ${e.message}');
      debugPrint('[Influx] Status  : ${e.response?.statusCode}');
      debugPrint('[Influx] Response: ${e.response?.data}');
      return [];
    } catch (e) {
      debugPrint('[Influx] ── UNEXPECTED ERROR ─────────────────────────');
      debugPrint('[Influx] $e');
      return [];
    }
  }

  List<InfluxPoint> _parseCsv(String csv) {
    final points = <InfluxPoint>[];
    final lines = csv.split('\n');

    List<String> headers = [];
    for (final line in lines) {
      if (line.isEmpty || line.startsWith('#')) continue;

      final cols = line.split(',');
      if (cols.isEmpty) continue;

      // Header row: starts with empty col AND second col is literally "result"
      if (cols[0] == '' && cols.length > 1 && cols[1] == 'result') {
        headers = cols;
        debugPrint('[Influx] CSV headers: $headers');
        continue;
      }

      // Data row: starts with empty col AND second col is "_result"
      if (cols[0] == '' && cols.length > 1 && cols[1] == '_result') {
        if (headers.isEmpty) continue;
        try {
          final row = Map.fromIterables(headers, cols);
          final timeStr = row['_time'];
          final fieldStr = row['_field'];
          final valueStr = row['_value'];
          final device = row['device'] ?? 'unknown';

          if (timeStr == null || fieldStr == null || valueStr == null) continue;

          final value = double.tryParse(valueStr);
          if (value == null) continue;

          points.add(InfluxPoint(
            time: DateTime.parse(timeStr),
            field: fieldStr,
            value: value,
            device: device,
          ));
        } catch (_) {
          continue;
        }
      }
    }
    debugPrint('[Influx] _parseCsv → ${points.length} points parsed');
    return points;
  }
}
