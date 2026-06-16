import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends State<AdminNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(160)),
              child: Container(
                  width: 160,
                  height: 140,
                  color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.chevron_left, size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Notifications',
                      style: GoogleFonts.poppins(
                          fontSize: 26, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Consumer<NotificationProvider>(
                    builder: (_, provider, __) {
                      if (provider.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary),
                        );
                      }
                      if (provider.items.isEmpty) {
                        return Center(
                          child: Text('No notifications',
                              style: GoogleFonts.poppins(
                                  color: Colors.grey)),
                        );
                      }
                      return ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: provider.items.length,
                        separatorBuilder: (_, __) => Divider(
                            color: Colors.grey.shade100, height: 32),
                        itemBuilder: (_, i) {
                          final item = provider.items[i];
                          return _NotifRow(
                            item: item,
                            onDismiss: () => provider.dismiss(item.id),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final NotifModel item;
  final VoidCallback onDismiss;

  const _NotifRow({required this.item, required this.onDismiss});

  Color get _color => switch (item.level) {
        NotifLevel.critical => Colors.red,
        NotifLevel.warning => Colors.orange,
        NotifLevel.info => Colors.blue,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: _color.withValues(alpha: 0.5), width: 1.5)),
          child: Icon(Icons.info_outline, color: _color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.level.name.toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _color)),
              const SizedBox(height: 2),
              Text(item.message,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.5)),
              if (item.device != null)
                Text(item.device!,
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
            onTap: onDismiss,
            child:
                const Icon(Icons.cancel, color: Colors.redAccent, size: 20)),
      ],
    );
  }
}
