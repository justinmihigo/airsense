import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(120),
                ),
              ),
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.chevron_left, size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Notifications',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                          child: Text(
                            'No notifications',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: provider.items.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.grey.shade100, height: 24),
                        itemBuilder: (_, i) {
                          final item = provider.items[i];
                          return _NotificationRow(
                            item: item,
                            onDismiss: () => provider.dismiss(item.id),
                            onTap: () => provider.markRead(item.id),
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

class _NotificationRow extends StatelessWidget {
  final NotifModel item;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.item,
    required this.onDismiss,
    required this.onTap,
  });

  Color get _levelColor => switch (item.level) {
        NotifLevel.critical => Colors.red,
        NotifLevel.warning => Colors.orange,
        NotifLevel.info => Colors.blue,
      };

  IconData get _levelIcon => switch (item.level) {
        NotifLevel.critical => Icons.warning_amber_rounded,
        NotifLevel.warning => Icons.info_outline,
        NotifLevel.info => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: item.read ? 0.6 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _levelColor.withValues(alpha: 0.5),
                    width: 1.5),
              ),
              child: Icon(_levelIcon, color: _levelColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.level.name.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _levelColor,
                        ),
                      ),
                      if (item.device != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${item.device}',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(item.createdAt),
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.cancel,
                  color: Colors.redAccent, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
