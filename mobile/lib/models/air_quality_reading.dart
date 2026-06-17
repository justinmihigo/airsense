enum AqiLevel { good, moderate, unhealthySensitive, unhealthy, severe }

class AirQualityReading {
  final int aqi;
  final double pm25;
  final double so2;
  final double co;
  final double o3;
  final double no2;
  final double temperature;
  final double humidity;
  final String critical;
  final DateTime updatedAt;

  const AirQualityReading({
    required this.aqi,
    required this.pm25,
    required this.so2,
    required this.co,
    required this.o3,
    required this.no2,
    required this.temperature,
    required this.humidity,
    required this.critical,
    required this.updatedAt,
  });

  AqiLevel get level {
    if (aqi <= 50) return AqiLevel.good;
    if (aqi <= 100) return AqiLevel.moderate;
    if (aqi <= 150) return AqiLevel.unhealthySensitive;
    if (aqi <= 200) return AqiLevel.unhealthy;
    return AqiLevel.severe;
  }

  String get levelLabel {
    switch (level) {
      case AqiLevel.good:
        return 'Good';
      case AqiLevel.moderate:
        return 'Moderate';
      case AqiLevel.unhealthySensitive:
        return 'Unhealthy (Sensitive)';
      case AqiLevel.unhealthy:
        return 'Unhealthy';
      case AqiLevel.severe:
        return 'Severe';
    }
  }

  String get levelDescription {
    switch (level) {
      case AqiLevel.good:
        return 'The air is fresh and toxin-free. People are not exposed to any health risks.';
      case AqiLevel.moderate:
        return 'Air quality is acceptable. Sensitive groups may experience minor discomfort.';
      case AqiLevel.unhealthySensitive:
        return 'Unhealthy for sensitive groups. May cause respiratory issues for some individuals.';
      case AqiLevel.unhealthy:
        return 'General public may experience health effects.';
      case AqiLevel.severe:
        return 'Serious risk of respiratory effects. Avoid outdoor activities.';
    }
  }

  factory AirQualityReading.fromJson(Map<String, dynamic> json) {
    return AirQualityReading(
      aqi: json['aqi'] as int,
      pm25: (json['pm25'] as num).toDouble(),
      so2: (json['so2'] as num).toDouble(),
      co: (json['co'] as num).toDouble(),
      o3: (json['o3'] as num).toDouble(),
      no2: (json['no2'] as num).toDouble(),
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      critical: json['critical'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'aqi': aqi,
        'pm25': pm25,
        'so2': so2,
        'co': co,
        'o3': o3,
        'no2': no2,
        'temperature': temperature,
        'humidity': humidity,
        'critical': critical,
        'updatedAt': updatedAt.toIso8601String(),
      };
}
