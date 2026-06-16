import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'auth/providers/auth_provider.dart';
import 'auth/services/auth_service.dart';
import 'core/network/dio_client.dart';
import 'core/storage/secure_storage.dart';
import 'providers/air_quality_provider.dart';
import 'providers/device_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/splash_screen.dart';
import 'services/device_service.dart';
import 'services/influx_service.dart';
import 'services/mqtt_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');

  final storage = SecureStorage();
  final dio = DioClient.create(storage);

  final mqttService = MqttService();
  final influxService = InfluxService(dio);
  final airQualityProvider = AirQualityProvider(mqttService, influxService, dio: dio);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthService(dio, storage)),
        ),
        ChangeNotifierProvider.value(value: mqttService),
        ChangeNotifierProvider.value(value: airQualityProvider),
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(DeviceService(dio)),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(NotificationService(dio)),
        ),
      ],
      child: const AirSenseApp(),
    ),
  );
}

class AirSenseApp extends StatefulWidget {
  const AirSenseApp({super.key});

  @override
  State<AirSenseApp> createState() => _AirSenseAppState();
}

class _AirSenseAppState extends State<AirSenseApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MqttService>().connect();
      context.read<AirQualityProvider>().startPolling();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AirSense',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
