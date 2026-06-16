class AqiDataPoint {
  final String label;
  final double value;

  const AqiDataPoint({required this.label, required this.value});
}

class AqiReport {
  final String title;
  final String subtitle;
  final List<AqiDataPoint> points;
  final int peakAqi;
  final DateTime peakDate;

  const AqiReport({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.peakAqi,
    required this.peakDate,
  });
}

class MapPin {
  final double lat;
  final double lng;
  final int aqi;
  final String stationId;

  const MapPin({
    required this.lat,
    required this.lng,
    required this.aqi,
    required this.stationId,
  });
}

class RoleMember {
  final String name;
  final String role;
  final List<String> permissions;

  const RoleMember({
    required this.name,
    required this.role,
    required this.permissions,
  });
}
