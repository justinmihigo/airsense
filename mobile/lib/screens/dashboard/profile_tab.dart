import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../sign_in_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'downloads_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Profile',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(Icons.settings_outlined, size: 24),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.grey.shade200,
                        child: const Icon(Icons.person,
                            size: 40, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '—',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              user?.email ?? '—',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const EditProfileScreen()),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Edit Profile',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _MenuItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen())),
                  ),
                  _MenuItem(
                    icon: Icons.download_outlined,
                    label: 'Downloads',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DownloadsScreen())),
                  ),
                  _MenuItem(
                    icon: Icons.logout_outlined,
                    label: 'Log Out',
                    onTap: () async {
                      await context.read<AuthProvider>().signOut();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignInScreen()),
                        (_) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, size: 22, color: Colors.black87),
          title: Text(
            label,
            style:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          onTap: onTap,
        ),
        Divider(color: Colors.grey.shade100, height: 1),
      ],
    );
  }
}
