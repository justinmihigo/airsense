import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../dashboard/widgets/aqi_utils.dart';
import '../../providers/device_provider.dart';
import '../../providers/air_quality_provider.dart';
import '../../services/device_service.dart';
import '../../theme/app_theme.dart';

class StationsTab extends StatefulWidget {
  const StationsTab({super.key});

  @override
  State<StationsTab> createState() => _StationsTabState();
}

class _StationsTabState extends State<StationsTab> {
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Navigator.canPop(context)
                      ? GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 20, color: Colors.black87),
                        )
                      : const Icon(Icons.menu, size: 24, color: Colors.black87),
                  Column(
                    children: [
                      const Icon(Icons.air_rounded,
                          size: 28, color: AppTheme.primary),
                      Text(
                        'AirSense.',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.search, size: 24, color: Colors.black87),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Add Station',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Consumer2<DeviceProvider, AirQualityProvider>(
                builder: (_, deviceProvider, aqProvider, __) {
                  if (deviceProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary),
                    );
                  }
                  if (deviceProvider.devices.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sensors_off,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No devices found',
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: deviceProvider.refresh,
                    child: ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: deviceProvider.devices.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 20),
                      itemBuilder: (_, i) {
                        final device = deviceProvider.devices[i];
                        final liveAqi = aqProvider.live?.device ==
                                device.deviceId
                            ? aqProvider.live!.aqi
                            : null;
                        return _DeviceCard(
                            device: device, liveAqi: liveAqi);
                      },
                    ),
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

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final int? liveAqi;

  const _DeviceCard({required this.device, this.liveAqi});

  @override
  Widget build(BuildContext context) {
    final aqi = liveAqi ?? 0;
    final color = liveAqi != null
        ? AqiUtils.colorForAqi(aqi)
        : Colors.grey.shade400;
    final label = liveAqi != null
        ? AqiUtils.labelForAqi(aqi)
        : device.isOnline ? 'Online' : 'Offline';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          device.name,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        device.isOnline
                            ? Icons.sensors
                            : Icons.sensors_off,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        device.location.isNotEmpty
                            ? device.location
                            : device.deviceId,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    device.deviceId,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                liveAqi != null ? '$aqi' : '—',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
