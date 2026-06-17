import 'package:dio/dio.dart';

class DeviceModel {
  final String id;
  final String name;
  final String location;
  final String deviceId;
  final String status;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.location,
    required this.deviceId,
    required this.status,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  bool get isOnline => status == 'active';

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        location: (json['location'] as String?) ?? '',
        deviceId: json['device_id'] as String,
        status: (json['status'] as String?) ?? 'inactive',
        createdAt: DateTime.parse(json['created_at'] as String),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class DeviceService {
  final Dio _dio;

  DeviceService(this._dio);

  Future<List<DeviceModel>> getDevices() async {
    final res = await _dio.get('/api/devices');
    final list = res.data as List<dynamic>;
    return list
        .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DeviceModel> createDevice({
    required String name,
    required String location,
    required String deviceId,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _dio.post('/api/devices', data: {
      'name': name,
      'location': location,
      'device_id': deviceId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return DeviceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<DeviceModel> updateDevice(
    String deviceId, {
    String? name,
    String? location,
    String? status,
  }) async {
    final res = await _dio.patch('/api/devices/$deviceId', data: {
      if (name != null) 'name': name,
      if (location != null) 'location': location,
      if (status != null) 'status': status,
    });
    return DeviceModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteDevice(String deviceId) =>
      _dio.delete('/api/devices/$deviceId');
}
