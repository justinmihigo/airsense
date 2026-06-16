import 'package:flutter/material.dart';
import '../../models/air_quality_reading.dart';

class AqiUtils {
  AqiUtils._();

  static Color colorFor(AqiLevel level) {
    switch (level) {
      case AqiLevel.good:
        return const Color(0xFF00B074);
      case AqiLevel.moderate:
        return const Color(0xFFF5A623);
      case AqiLevel.unhealthySensitive:
        return const Color(0xFFFF6B35);
      case AqiLevel.unhealthy:
        return const Color(0xFFE53935);
      case AqiLevel.severe:
        return const Color(0xFF7B1FA2);
    }
  }

  static Color colorForAqi(int aqi) {
    if (aqi <= 50) return const Color(0xFF00B074);
    if (aqi <= 100) return const Color(0xFFF5A623);
    if (aqi <= 150) return const Color(0xFFFF6B35);
    if (aqi <= 200) return const Color(0xFFE53935);
    return const Color(0xFF7B1FA2);
  }

  static String labelForAqi(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    return 'Severe';
  }
}
