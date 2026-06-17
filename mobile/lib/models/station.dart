import 'air_quality_reading.dart';

class Station {
  final String id;
  final String name;
  final String location;
  final String city;
  final String building;
  final AirQualityReading reading;
  final bool isOwned;

  const Station({
    required this.id,
    required this.name,
    required this.location,
    required this.city,
    required this.building,
    required this.reading,
    this.isOwned = false,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      city: json['city'] as String,
      building: json['building'] as String,
      reading: AirQualityReading.fromJson(json['reading'] as Map<String, dynamic>),
      isOwned: json['isOwned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'city': city,
        'building': building,
        'reading': reading.toJson(),
        'isOwned': isOwned,
      };
}
