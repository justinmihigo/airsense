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
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              auth.user!.isAdmin ? const AdminShell() : const HomeScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Sign in failed')),
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
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                              fontSize: 18, color: Colors.black),
                          children: [
                            TextSpan(
                              text: 'Sign in ',
                              style: GoogleFonts.poppins(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            const TextSpan(text: 'to your account'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
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
                        hint: 'Enter Password',
                        prefixIcon: Icons.lock_outline_rounded,
                        controller: _passwordController,
                        isPassword: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Password is required' : null,
                      ),
                      const SizedBox(height: 8),
                      Consumer<AuthProvider>(
                        builder: (_, auth, __) => AuthButton(
                          label: 'Sign In',
                          onTap: _onSignIn,
                          isLoading: auth.isLoading,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.black87),
                            children: [
                              const TextSpan(text: "Don't have an Account?  "),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const SignUpScreen()),
                                  ),
                                  child: Text(
                                    'Sign Up',
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
