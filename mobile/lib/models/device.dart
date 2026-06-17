import 'air_quality_reading.dart';

class Device {
  final String id;
  final String name;
  final String stationId;
  final String stationName;
  final String location;
  final AirQualityReading reading;
  final bool isOnline;

  const Device({
    required this.id,
    required this.name,
    required this.stationId,
    required this.stationName,
    required this.location,
    required this.reading,
    this.isOnline = true,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String,
        stationId: json['stationId'] as String,
        stationName: json['stationName'] as String,
        location: json['location'] as String,
        reading: AirQualityReading.fromJson(
            json['reading'] as Map<String, dynamic>),
        isOnline: json['isOnline'] as bool? ?? true,
      );
}
