import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'Welcome_Screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      icon: Icons.cell_tower_rounded,
      title: 'Track Air Quality Instantly',
      description:
          'Our smart monitoring system provides real-time air quality data for a healthier environment.',
      showBack: false,
      showSkip: false,
      buttonLabel: 'Next',
    ),
    _OnboardingData(
      icon: Icons.monitor_heart_outlined,
      title: 'Smart Air Quality Guidance',
      description:
          'Protect yourself with real-time recommendations based on air pollution levels.',
      showBack: true,
      showSkip: true,
      buttonLabel: 'Next',
    ),
    _OnboardingData(
      icon: Icons.foundation_rounded,
      title: 'Know Your Air, Breathe Healthier',
      description:
          'Real-time air quality data to create healthier spaces. Join us in making a difference.',
      showBack: true,
      showSkip: true,
      buttonLabel: 'Begin!',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToWelcome();
    }
  }

  void _back() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _goToWelcome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
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
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemCount: _pages.length,
                        itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
                      ),
                    ),
                    _buildDots(),
                    const SizedBox(height: 24),
                    _buildButton(),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final page = _pages[_currentPage];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (page.showBack)
            GestureDetector(
              onTap: _back,
              child: const Icon(Icons.chevron_left, size: 28, color: Colors.black87),
            )
          else
            const SizedBox(width: 28),
          if (page.showSkip)
            GestureDetector(
              onTap: _goToWelcome,
              child: Text(
                'Skip',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 10 : 8,
          height: active ? 10 : 8,
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildButton() {
    return GestureDetector(
      onTap: _next,
      child: Container(
        width: 180,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            _pages[_currentPage].buttonLabel,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8F8F1), AppTheme.primary],
              ),
            ),
            child: Center(
              child: Icon(
                data.icon,
                size: 100,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.left,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.description,
            textAlign: TextAlign.left,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final String title;
  final String description;
  final bool showBack;
  final bool showSkip;
  final String buttonLabel;

  const _OnboardingData({
    required this.icon,
    required this.title,
    required this.description,
    required this.showBack,
    required this.showSkip,
    required this.buttonLabel,
  });
}
