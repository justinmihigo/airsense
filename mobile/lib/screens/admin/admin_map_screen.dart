import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../dashboard/widgets/aqi_utils.dart';
import '../../providers/air_quality_provider.dart';
import '../../providers/device_provider.dart';
import '../../theme/app_theme.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle),
                      child: const Icon(
                          Icons.arrow_back_ios_new_rounded, size: 16),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'AirSense.',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer2<DeviceProvider, AirQualityProvider>(
                builder: (_, deviceProvider, aqProvider, __) {
                  final devices = deviceProvider.devices
                      .where((d) =>
                          d.latitude != null && d.longitude != null)
                      .toList();

                  return Stack(
                    children: [
                      Container(color: const Color(0xFFD9EAD3)),
                      if (devices.isEmpty)
                        Center(
                          child: Text(
                            deviceProvider.isLoading
                                ? 'Loading devices...'
                                : 'No devices with location data',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600),
                          ),
                        )
                      else
                        _DeviceMapGrid(
                          devices: devices
                              .map((d) => _DevicePin(
                                    lat: d.latitude!,
                                    lng: d.longitude!,
                                    label: d.name,
                                    aqi: aqProvider.live?.device ==
                                            d.deviceId
                                        ? aqProvider.live!.aqi
                                        : null,
                                    isOnline: d.isOnline,
                                  ))
                              .toList(),
                        ),
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            'Data powered by AirSense.',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicePin {
  final double lat;
  final double lng;
  final String label;
  final int? aqi;
  final bool isOnline;

  const _DevicePin({
    required this.lat,
    required this.lng,
    required this.label,
    required this.isOnline,
    this.aqi,
  });
}

class _DeviceMapGrid extends StatelessWidget {
  final List<_DevicePin> devices;

  const _DeviceMapGrid({required this.devices});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (devices.isEmpty) return const SizedBox();

    final lats = devices.map((d) => d.lat);
    final lngs = devices.map((d) => d.lng);
    final latMin = lats.reduce((a, b) => a < b ? a : b) - 0.005;
    final latMax = lats.reduce((a, b) => a > b ? a : b) + 0.005;
    final lngMin = lngs.reduce((a, b) => a < b ? a : b) - 0.005;
    final lngMax = lngs.reduce((a, b) => a > b ? a : b) + 0.005;

    return Stack(
      children: devices.map((pin) {
        final x = ((pin.lng - lngMin) / (lngMax - lngMin)) *
            (size.width - 40);
        final y = ((pin.lat - latMin) / (latMax - latMin)) *
            (size.height * 0.7);
        final color = pin.aqi != null
            ? AqiUtils.colorForAqi(pin.aqi!)
            : pin.isOnline
                ? AppTheme.primary
                : Colors.grey;

        return Positioned(
          left: x.clamp(0.0, size.width - 60),
          top: y.clamp(0.0, size.height * 0.65),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Text(
              pin.aqi != null ? '${pin.aqi}' : '—',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        );
      }).toList(),
    );
  }
}
