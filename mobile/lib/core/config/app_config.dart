import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String get apiBaseUrl => dotenv.env['API_BASE_URL']!;
  static String get mqttUrl => dotenv.env['MQTT_URL']!;
  static String get mqttTopic => dotenv.env['MQTT_TOPIC']!;
  static String get influxUrl => dotenv.env['INFLUX_URL']!;
  static String get influxBucket => dotenv.env['INFLUX_BUCKET']!;
  static String get influxOrg => dotenv.env['INFLUX_ORG']!;
  static String get influxToken => dotenv.env['INFLUX_TOKEN']!;
  static String get influxMeasurement => dotenv.env['INFLUX_MEASUREMENT']!;
}
