import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/widgets/auth_button.dart';
import '../../theme/app_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _emailAlerts = false;
  bool _twoFactor = false;
  bool _verifyNumber = false;

  static const _roleMembers = [
    _RoleMember(
      name: 'Admin',
      role: 'Owner',
      permissions: ['Create', 'View', 'Update', 'Delete'],
    ),
    _RoleMember(
      name: 'User',
      role: 'Guest',
      permissions: ['View'],
    ),
  ];

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
              borderRadius:
                  const BorderRadius.only(bottomLeft: Radius.circular(160)),
              child: Container(
                  width: 160,
                  height: 140,
                  color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
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
                  const SizedBox(height: 40),
                  Center(
                    child: Text('Settings',
                        style: GoogleFonts.poppins(
                            fontSize: 26, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 28),
                  Text('Alerts and notifications',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  _ToggleTile(
                    label:
                        'Get email and notifications about daily updates and alerts',
                    value: _emailAlerts,
                    onChanged: (v) => setState(() => _emailAlerts = v),
                  ),
                  const SizedBox(height: 12),
                  _ToggleTile(
                    label: 'Enable two factor authentication, ',
                    linkText: 'verify',
                    value: _twoFactor,
                    onChanged: (v) => setState(() => _twoFactor = v),
                  ),
                  const SizedBox(height: 12),
                  _ToggleTile(
                    label: 'Verify your number, ',
                    linkText: 'verify',
                    value: _verifyNumber,
                    onChanged: (v) => setState(() => _verifyNumber = v),
                  ),
                  const SizedBox(height: 24),
                  AuthButton(
                      label: 'Save settings',
                      onTap: () => Navigator.pop(context)),
                  const SizedBox(height: 36),
                  Text('Roles and Permissions',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(3),
                    },
                    children: [
                      TableRow(
                        children: [
                          Text('Users',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey.shade500)),
                          Text('Role',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey.shade500)),
                          Text('Permissions',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: Colors.grey.shade500)),
                        ],
                      ),
                      ..._roleMembers.map(
                        (m) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(m.name,
                                  style:
                                      GoogleFonts.poppins(fontSize: 13)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(m.role,
                                  style:
                                      GoogleFonts.poppins(fontSize: 13)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(m.permissions.join(',  '),
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey.shade700)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  AuthButton(label: 'Update Roles', onTap: () {}),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleMember {
  final String name;
  final String role;
  final List<String> permissions;

  const _RoleMember(
      {required this.name, required this.role, required this.permissions});
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final String? linkText;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile(
      {required this.label,
      this.linkText,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: linkText != null
              ? RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.black87),
                    children: [
                      TextSpan(text: label),
                      TextSpan(
                          text: linkText,
                          style: GoogleFonts.poppins(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.black87)),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primary,
          inactiveThumbColor: Colors.grey.shade400,
          inactiveTrackColor: Colors.grey.shade200,
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ],
    );
  }
}
