import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class BuddhistDayBadge extends StatelessWidget {
  const BuddhistDayBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.getBuddhistDays(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));

        bool isToday = false;
        bool isTomorrow = false;

        for (var day in snapshot.data!) {
          final dayDate = day['date'].toString().split('T')[0];
          if (dayDate == todayStr) {
            isToday = true;
            break;
          }
          if (dayDate == tomorrowStr) {
            isTomorrow = true;
          }
        }

        if (isToday) {
          return _buildBadge(
            text: 'วันนี้วันพระ',
            bgColor: const Color(0xFFFFD700).withOpacity(0.2),
            borderColor: const Color(0xFFFFD700),
            textColor: const Color(0xFFFFD700),
          );
        } else if (isTomorrow) {
          return _buildBadge(
            text: 'พรุ่งนี้วันพระ',
            bgColor: Colors.white.withOpacity(0.15),
            borderColor: Colors.white.withOpacity(0.3),
            textColor: const Color(0xFFE2E8F0),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBadge({
    required String text,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.kanit(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
