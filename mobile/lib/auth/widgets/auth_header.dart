import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.air_rounded, size: 40, color: Colors.white),
        const SizedBox(height: 6),
        Text(
          'Airsense.',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'For Shared Spaces!',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
