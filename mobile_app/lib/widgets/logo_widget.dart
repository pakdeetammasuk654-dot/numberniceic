import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LogoWidget extends StatelessWidget {
  final double size;

  const LogoWidget({
    super.key,
    this.size = 512,
  });

  @override
  Widget build(BuildContext context) {
    // Scaling factor based on the original 512px SVG design
    final scale = size / 512;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. The Gold Coin (Circle)
          Container(
            width: size * (480 / 512),
            height: size * (480 / 512),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFB8860B),
                width: 4 * scale,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFDE7),
                  Color(0xFFFFD700),
                  Color(0xFFFBC02D),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // 2. The Text "ช" with Emboss-like effects using Shadows
          // Note: In SVG it was positioned at y=375 (from top). 
          // 375/512 is about 0.73 of height. Custom positioning with Transform.
          Transform.translate(
            offset: Offset(0, size * (-30 / 512)), // Moved up to align closer to top edge
            child: Text(
              'ช',
              textAlign: TextAlign.center,
              style: GoogleFonts.kanit(
                fontSize: 420 * scale,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF27AE60),
                height: 1.0,
                shadows: [
                  // Light Shadow (Top-Left) - Emboss Highlight
                  Shadow(
                    offset: Offset(-4 * scale, -4 * scale),
                    blurRadius: 1 * scale,
                    color: const Color(0xFFD5F5E3).withOpacity(0.5),
                  ),
                  // Dark Shadow (Bottom-Right) - Emboss Shadow
                  Shadow(
                    offset: Offset(4 * scale, 4 * scale),
                    blurRadius: 4 * scale,
                    color: const Color(0xFF145A32).withOpacity(0.4),
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
