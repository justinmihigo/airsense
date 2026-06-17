import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../auth/providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'admin/admin_shell.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2000)),
      context.read<AuthProvider>().restoreSession(),
    ]);

    if (!mounted) return;

    final auth = context.read<AuthProvider>();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (auth.isAuthenticated) {
            return auth.user!.isAdmin
                ? const AdminShell()
                : const HomeScreen();
          }
          return const OnboardingScreen();
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cornerRadius = size.width * 0.45;

    return Scaffold(
      backgroundColor: AppTheme.backgroundTeal,
      body: Stack(
        children: [
          Positioned(
            top: -cornerRadius * 0.35,
            right: -cornerRadius * 0.35,
            child: Container(
              width: cornerRadius * 1.4,
              height: cornerRadius * 1.4,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -cornerRadius * 0.35,
            left: -cornerRadius * 0.35,
            child: Container(
              width: cornerRadius * 1.4,
              height: cornerRadius * 1.4,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: size.width * 0.06),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: SizedBox(
                width: double.infinity,
                height: size.height * 0.88,
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.air_rounded,
                            size: 64,
                            color: Colors.black87,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'AirSense.',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
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
