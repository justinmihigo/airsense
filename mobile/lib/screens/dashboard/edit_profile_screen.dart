import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/auth_button.dart';
import '../../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _idController;
  late final TextEditingController _emailController;

  String? _selectedGender;
  String? _selectedBirth;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _roleController = TextEditingController(text: user?.role ?? '');
    _idController = TextEditingController(text: user?.id ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _idController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 130,
                  color: AppTheme.primary,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.chevron_left,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(Icons.person,
                              size: 48, color: Colors.grey),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.edit,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text('Edit Profile',
                        style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 24),
                  _FieldLabel('Full Name'),
                  _ProfileField(controller: _nameController),
                  const SizedBox(height: 14),
                  _FieldLabel('Role'),
                  _ProfileField(
                      controller: _roleController, enabled: false),
                  const SizedBox(height: 14),
                  _FieldLabel('User ID'),
                  _ProfileField(controller: _idController, enabled: false),
                  const SizedBox(height: 14),
                  _FieldLabel('Email'),
                  _ProfileField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _DropdownField(
                    hint: 'Birth Year',
                    value: _selectedBirth,
                    onChanged: (v) =>
                        setState(() => _selectedBirth = v),
                    items: const [
                      '1980', '1985', '1990', '1995', '2000', '2005'
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DropdownField(
                    hint: 'Gender',
                    value: _selectedGender,
                    onChanged: (v) =>
                        setState(() => _selectedGender = v),
                    items: const ['Male', 'Female', 'Other'],
                  ),
                  const SizedBox(height: 28),
                  AuthButton(
                      label: 'Save Changes',
                      onTap: () => Navigator.pop(context)),
                  const SizedBox(height: 12),
                  AuthButton(
                    label: 'Change Password  🔒',
                    onTap: () {},
                    color: AppTheme.primaryDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.grey.shade600)),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final TextInputType keyboardType;

  const _ProfileField({
    required this.controller,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.primary, width: 1.5)),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String hint;
  final String? value;
  final ValueChanged<String?> onChanged;
  final List<String> items;

  const _DropdownField({
    required this.hint,
    required this.value,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint,
          style:
              GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
      onChanged: onChanged,
      items: items
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e,
                  style: GoogleFonts.poppins(fontSize: 13))))
          .toList(),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.primary, width: 1.5)),
      ),
    );
  }
}
