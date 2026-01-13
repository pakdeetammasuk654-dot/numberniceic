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
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/logo_gold_name_transparent.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
