import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.mainGradient),
        child: Column(
          children: [
            const Spacer(flex: 2),
            const Icon(Icons.air_rounded, size: 80, color: Colors.white),
            const Text(
              'AIRSENSE',
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold, 
                color: Colors.white, 
                letterSpacing: 2
              ),
            ),
            const Spacer(),
            const Text(
              'Welcome Back',
              style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),
            _buildButton(context, 'SIGN IN', Colors.transparent, Colors.white, const SignInScreen()),
            const SizedBox(height: 15),
            _buildButton(context, 'SIGN UP', Colors.white, Colors.black, const SignUpScreen()),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text, Color bg, Color textCol, Widget target) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => target)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 55,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white),
        ),
        child: Center(child: Text(text, style: TextStyle(color: textCol, fontWeight: FontWeight.bold))),
      ),
    );
  }
}