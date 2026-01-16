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
            icon: Icons.self_improvement, 
            imagePath: 'assets/images/buddha.png',
            color: const Color(0xFFD97706), // Amber-600
            message: 'วันนี้วันพระ',
            showText: true,
          );
        } else if (isTomorrow) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return _buildIconBadge(
            icon: Icons.self_improvement,
            imagePath: 'assets/images/buddha.png',
            color: isDark ? Colors.white70 : Colors.black87, // Subtle color
            message: 'พรุ่งนี้วันพระ',
            showText: true,
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
    String? imagePath,
    bool showText = false,
  }) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showText) ...[
              Text(
                message,
                style: GoogleFonts.kanit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
            ],
            imagePath != null ? Image.asset(
              imagePath,
              width: 24,
              height: 24,
              color: color, // Apply color filter
            ) : Icon(
              icon,
              color: color,
              size: 18, 
            ),
          ],
        ),
      ),
    );
  }
}
