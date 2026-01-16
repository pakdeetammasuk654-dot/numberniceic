import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart'; // For rootBundle

class BuddhistDayBadge extends StatelessWidget {
  const BuddhistDayBadge({super.key});

  Future<List<dynamic>> _loadBuddhistDays() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/buddhist_days.json');
      return json.decode(jsonString) as List<dynamic>;
    } catch (e) {
      print("Error loading buddhist days badge: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _loadBuddhistDays(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));

        bool isToday = false;
        bool isTomorrow = false;

        for (var day in snapshot.data!) {
          String dateStr = day['date'].toString();
          if (dateStr.length > 10) dateStr = dateStr.substring(0, 10);
          
          if (dateStr == todayStr) {
            isToday = true;
            break;
          }
          if (dateStr == tomorrowStr) {
            isTomorrow = true;
          }
        }

        if (isToday) {
          return _buildIconBadge(
            icon: Icons.self_improvement, // Meditation/Buddha icon
            color: const Color(0xFFFFD700),
            message: 'วันนี้วันพระ',
          );
        } else if (isTomorrow) {
          // Keep the minimal style for tomorrow warning
          return _buildIconBadge(
            icon: Icons.spa_outlined,
            color: const Color(0xFFE2E8F0), 
            message: 'พรุ่งนี้วันพระ',
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildIconBadge({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Image.asset(
          'assets/images/buddha.png',
          width: 20,
          height: 20,
          // color: color, // Removed color tint to show original image
        ),
      ),
    );
  }
}
