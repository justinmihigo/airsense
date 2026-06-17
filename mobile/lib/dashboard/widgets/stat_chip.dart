import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
