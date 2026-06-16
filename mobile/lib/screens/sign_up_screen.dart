import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/widgets/auth_button.dart';
import '../auth/widgets/auth_header.dart';
import '../auth/widgets/auth_text_field.dart';
import '../theme/app_theme.dart';
import 'admin/admin_shell.dart';
import 'home_screen.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              auth.user!.isAdmin ? const AdminShell() : const HomeScreen(),
        ),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Sign up failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Column(
        children: [
          const SizedBox(height: 70),
          const AuthHeader(),
          const SizedBox(height: 30),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign Up',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.black54),
                          children: [
                            const TextSpan(text: 'Already have an Account?  '),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SignInScreen()),
                                ),
                                child: Text(
                                  'Sign In',
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      AuthTextField(
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        prefixIcon: Icons.person_outline_rounded,
                        controller: _nameController,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Email',
                        hint: 'Enter email address',
                        prefixIcon: Icons.mail_outline_rounded,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Password',
                        hint: 'Enter password',
                        prefixIcon: Icons.lock_outline_rounded,
                        controller: _passwordController,
                        isPassword: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 6) return 'At least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      Consumer<AuthProvider>(
                        builder: (_, auth, __) => AuthButton(
                          label: 'Sign Up',
                          onTap: _onSignUp,
                          isLoading: auth.isLoading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
