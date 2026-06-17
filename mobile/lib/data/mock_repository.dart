import '../models/air_quality_reading.dart';
import '../models/app_notification.dart';
import '../models/aqi_report.dart';
import '../models/device.dart';
import '../models/download_item.dart';
import '../models/station.dart';
import '../models/user_profile.dart';

class MockRepository {
  MockRepository._();
  static final MockRepository instance = MockRepository._();

  static final _now = DateTime(2025, 3, 12, 11, 0);

  static AirQualityReading _reading({
    int aqi = 47,
    double pm25 = 30,
    double so2 = 20,
    double co = 10,
    double o3 = 32,
    double no2 = 9,
    double temperature = 31,
    double humidity = 74,
    String critical = 'O3',
  }) =>
      AirQualityReading(
        aqi: aqi,
        pm25: pm25,
        so2: so2,
        co: co,
        o3: o3,
        no2: no2,
        temperature: temperature,
        humidity: humidity,
        critical: critical,
        updatedAt: _now,
      );

  Station get primaryStation => Station(
        id: 'p001',
        name: 'MUHABURA Station',
        location: 'Ur-Cst, Kigali',
        city: 'Kigali',
        building: 'p001',
        reading: _reading(),
      );

  List<Station> get recentStations => [
        Station(
          id: 'p001',
          name: 'MUHABURA Station, p001',
          location: 'Ur-Cst, Kigali',
          city: 'Kigali',
          building: 'p001',
          reading: _reading(),
        ),
        Station(
          id: 'p002',
          name: 'KALISIMBI, 3F-lab 22',
          location: 'Ur-Cst, Kigali',
          city: 'Kigali',
          building: '3F-lab 22',
          reading: _reading(aqi: 51, pm25: 31, so2: 7, co: 8, o3: 41, no2: 5, temperature: 33, humidity: 81),
        ),
        Station(
          id: 'p003',
          name: 'LIBRARY, 1F',
          location: 'Ur-Cst, Kigali',
          city: 'Kigali',
          building: '1F',
          reading: _reading(aqi: 45, pm25: 38, so2: 11, co: 25, o3: 0, no2: 0, temperature: 30, humidity: 0),
        ),
      ];

  List<Station> get myStations => [
        Station(
          id: 's001',
          name: 'EINSTEIN, R09',
          location: 'Einstein building, Room 09',
          city: 'Kigali',
          building: 'AirTest',
          reading: _reading(aqi: 55, pm25: 31, temperature: 33, humidity: 80),
          isOwned: true,
        ),
        Station(
          id: 's002',
          name: 'AGACIRO, lab 1F-05',
          location: 'Agaciro building, lab 1F-05',
          city: 'Kigali',
          building: 'AirTest',
          reading: _reading(aqi: 45, temperature: 31, humidity: 74),
          isOwned: true,
        ),
      ];

  UserProfile get currentUser => const UserProfile(
        id: 'u001',
        firstName: 'Axelle',
        lastName: 'Isimbi',
        username: 'axelle_isimbi',
        email: 'axellejustin208@gmailcom',
        phone: '+250 788668709',
        role: 'Guest',
        avatarUrl: null,
      );

  List<AppNotification> get notifications => [
        AppNotification(
          id: 'n1',
          category: NotificationCategory.dailyUpdate,
          title: 'Daily update',
          message: 'The air quality at Muhabura station, p001 is looking good!',
          createdAt: _now,
        ),
        AppNotification(
          id: 'n2',
          category: NotificationCategory.password,
          title: 'password',
          message: 'Remember to Reset your password before March 22, 2025',
          createdAt: _now,
        ),
        AppNotification(
          id: 'n3',
          category: NotificationCategory.dailyUpdate,
          title: 'Daily update',
          message: 'The air quality at Muhabura station, p001 is looking good!',
          createdAt: _now,
        ),
      ];

  int get totalStations => 5;
  int get totalDevices => 100;

  List<Device> get devices => [
        Device(
          id: 'dev001',
          name: 'MUHABURA, p001',
          stationId: 'p001',
          stationName: 'MUHABURA Station',
          location: 'Kigali, Nyarugenge',
          reading: _reading(pm25: 400, co: 239, temperature: 400, humidity: 400, so2: 400, no2: 400),
        ),
      ];

  List<MapPin> get mapPins => const [
        MapPin(lat: -1.935, lng: 30.045, aqi: 29, stationId: 'p001'),
        MapPin(lat: -1.930, lng: 30.060, aqi: 33, stationId: 'p002'),
        MapPin(lat: -1.940, lng: 30.070, aqi: 32, stationId: 'p003'),
        MapPin(lat: -1.925, lng: 30.080, aqi: 31, stationId: 'p004'),
        MapPin(lat: -1.950, lng: 30.055, aqi: 72, stationId: 'p005'),
        MapPin(lat: -1.955, lng: 30.050, aqi: 79, stationId: 'p006'),
        MapPin(lat: -1.958, lng: 30.048, aqi: 72, stationId: 'p007'),
        MapPin(lat: -1.945, lng: 30.040, aqi: 58, stationId: 'p008'),
        MapPin(lat: -1.960, lng: 30.065, aqi: 75, stationId: 'p009'),
        MapPin(lat: -1.965, lng: 30.060, aqi: 76, stationId: 'p010'),
        MapPin(lat: -1.970, lng: 30.070, aqi: 71, stationId: 'p011'),
        MapPin(lat: -1.948, lng: 30.085, aqi: 51, stationId: 'p012'),
        MapPin(lat: -1.952, lng: 30.090, aqi: 51, stationId: 'p013'),
        MapPin(lat: -1.975, lng: 30.055, aqi: 52, stationId: 'p014'),
        MapPin(lat: -1.980, lng: 30.060, aqi: 28, stationId: 'p015'),
        MapPin(lat: -1.985, lng: 30.065, aqi: 69, stationId: 'p016'),
        MapPin(lat: -1.963, lng: 30.095, aqi: 62, stationId: 'p017'),
        MapPin(lat: -1.942, lng: 30.100, aqi: 51, stationId: 'p018'),
        MapPin(lat: -1.955, lng: 30.110, aqi: 86, stationId: 'p019'),
        MapPin(lat: -1.990, lng: 30.070, aqi: 29, stationId: 'p020'),
        MapPin(lat: -1.995, lng: 30.075, aqi: 32, stationId: 'p021'),
        MapPin(lat: -2.000, lng: 30.060, aqi: 51, stationId: 'p022'),
        MapPin(lat: -1.988, lng: 30.080, aqi: 30, stationId: 'p023'),
        MapPin(lat: -2.005, lng: 30.065, aqi: 29, stationId: 'p024'),
        MapPin(lat: -2.010, lng: 30.070, aqi: 25, stationId: 'p025'),
        MapPin(lat: -2.008, lng: 30.055, aqi: 30, stationId: 'p026'),
        MapPin(lat: -2.015, lng: 30.060, aqi: 28, stationId: 'p027'),
        MapPin(lat: -2.012, lng: 30.080, aqi: 21, stationId: 'p028'),
        MapPin(lat: -1.978, lng: 30.090, aqi: 90, stationId: 'p029'),
        MapPin(lat: -2.020, lng: 30.065, aqi: 33, stationId: 'p030'),
        MapPin(lat: -1.933, lng: 30.050, aqi: 63, stationId: 'p031'),
        MapPin(lat: -1.935, lng: 30.052, aqi: 68, stationId: 'p032'),
      ];

  AqiReport get weeklyReport => AqiReport(
        title: 'Weekly report',
        subtitle: 'The weekly levels of overall report on air quality',
        peakAqi: 456,
        peakDate: DateTime(2025, 10, 19),
        points: const [
          AqiDataPoint(label: 'MON', value: 180),
          AqiDataPoint(label: 'TUE', value: 210),
          AqiDataPoint(label: 'WED', value: 456),
          AqiDataPoint(label: 'THU', value: 300),
          AqiDataPoint(label: 'FRI', value: 380),
          AqiDataPoint(label: 'SAT', value: 250),
          AqiDataPoint(label: 'SUN', value: 310),
        ],
      );

  AqiReport get monthlyReport => AqiReport(
        title: 'Monthly report',
        subtitle: 'The monthly levels of overall report on air quality',
        peakAqi: 456,
        peakDate: DateTime(2025, 10, 19),
        points: const [
          AqiDataPoint(label: 'JAN', value: 200),
          AqiDataPoint(label: 'FEB', value: 280),
          AqiDataPoint(label: 'MAR', value: 350),
          AqiDataPoint(label: 'APR', value: 456),
          AqiDataPoint(label: 'MAY', value: 300),
          AqiDataPoint(label: 'JUN', value: 220),
          AqiDataPoint(label: 'JULY', value: 260),
        ],
      );

  List<AqiDataPoint> get weeklyBarData => const [
        AqiDataPoint(label: 'Mo', value: 60),
        AqiDataPoint(label: 'Tue', value: 80),
        AqiDataPoint(label: 'we', value: 45),
        AqiDataPoint(label: 'thu', value: 65),
        AqiDataPoint(label: 'fri', value: 60),
        AqiDataPoint(label: 'sat', value: 20),
        AqiDataPoint(label: 'Sun', value: 60),
      ];

  List<RoleMember> get roleMembers => const [
        RoleMember(
          name: 'Samantha Jones',
          role: 'Owner',
          permissions: ['Create', 'View', 'Update and Delete'],
        ),
        RoleMember(
          name: 'Justin Mihigo',
          role: 'Guest',
          permissions: ['View'],
        ),
      ];

  List<AppNotification> get adminNotifications => [
        AppNotification(
          id: 'an1',
          category: NotificationCategory.dailyUpdate,
          title: 'Daily update',
          message: "See today's air quality!",
          createdAt: _now,
        ),
        AppNotification(
          id: 'an2',
          category: NotificationCategory.alert,
          title: 'Manage Devices',
          message: 'Device numbers for Muhabura station, p001 has exceed the limit!',
          createdAt: _now,
        ),
        AppNotification(
          id: 'an3',
          category: NotificationCategory.dailyUpdate,
          title: 'Daily update',
          message: 'The air quality at Eintsein , R09 is looking good!',
          createdAt: _now,
        ),
      ];

  List<DownloadItem> get downloads => [
        DownloadItem(
          id: 'd1',
          stationName: 'Muhabura station, p001',
          title: 'Status!',
          status: DownloadStatus.inProgress,
          requestedAt: _now,
        ),
        DownloadItem(
          id: 'd2',
          stationName: 'Download is complete!',
          title: 'Successful!',
          status: DownloadStatus.success,
          requestedAt: _now,
        ),
        DownloadItem(
          id: 'd3',
          stationName: 'Download queued.',
          title: 'Pending',
          status: DownloadStatus.pending,
          requestedAt: _now,
        ),
      ];
}
