import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalysisToggles extends StatelessWidget {
  final bool showGoodOnly;
  final bool enabled;
  final ValueChanged<bool>? onToggleGoodOnly;

  const AnalysisToggles({
    Key? key,
    required this.showGoodOnly,
    this.enabled = true,
    this.onToggleGoodOnly,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12), // Reduced padding from 16 to 4
      child: Center(
        child: Opacity(
          opacity: enabled ? 1.0 : 0.6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
            decoration: BoxDecoration(
              color: isDark 
                  ? (showGoodOnly ? const Color(0xFF2C250E) : const Color(0xFF1E293B))
                  : (showGoodOnly ? const Color(0xFFFFF9C4) : const Color(0xFFF1F5F9)), // Yellow 100 or Slate 100
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: showGoodOnly ? const Color(0xFFFFD54F) : (isDark ? Colors.white12 : Colors.grey[300]!), 
                width: 1.5
              ),
              boxShadow: [
                if (showGoodOnly)
                  BoxShadow(color: const Color(0xFFFFD54F).withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: showGoodOnly ? const Color(0xFFFFD700) : (isDark ? Colors.white24 : Colors.grey[400]), 
                    shape: BoxShape.circle
                  ), 
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 14), // Reduced icon size
                ),
                const SizedBox(width: 4), // Reduced from 8 to 4
                Text(
                  "แสดงชื่อดีเท่านั้น",
                  style: GoogleFonts.kanit(
                    fontSize: 13, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: isDark 
                        ? (showGoodOnly ? const Color(0xFFFFD700) : Colors.white60)
                        : (showGoodOnly ? const Color(0xFF1B5E20) : Colors.grey[600]), // Dark Green or Grey
                  ),
                ),
                const SizedBox(width: 4), // Reduced spacing before switch
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: showGoodOnly,
                    onChanged: enabled ? onToggleGoodOnly : null,
                    activeColor: const Color(0xFFFBC02D),
                    activeTrackColor: isDark ? Colors.white24 : Colors.white,
                    inactiveThumbColor: isDark ? Colors.white24 : Colors.grey[400],
                    inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
