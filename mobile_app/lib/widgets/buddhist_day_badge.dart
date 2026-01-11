import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class BuddhistDayBadge extends StatelessWidget {
  const BuddhistDayBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ApiService.isBuddhistDayToday(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          return Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🌕',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  'วันนี้วันพระ',
                  style: GoogleFonts.kanit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
