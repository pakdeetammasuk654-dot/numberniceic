import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/screens/vip_grade_info_page.dart'; // Import navigation target

class WreathScoreGrid extends StatelessWidget {
  const WreathScoreGrid({super.key});

  static const List<String> labels = [
    "เลขศาสตร์", "พลังเงา", "ผลรวม",
    "เลขเรียง", "คู่หลัก", "คู่แฝง"
  ];

  @override
  Widget build(BuildContext context) {
    // Layout manually to ensure stability and prevent overlapping
    final row1 = ["เลขศาสตร์", "พลังเงา", "ผลรวม"];
    final row2 = ["เลขเรียง", "คู่หลัก", "คู่แฝง"];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Fix: Use minimum space needed
        children: [
          _buildRow(context, row1),
          const SizedBox(height: 24), 
          _buildRow(context, row2),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> items) {
    // Calculate fixed width: (Screen Width - Padding) / 3
    final itemWidth = (MediaQuery.of(context).size.width - 48) / 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((label) => SizedBox(
        width: itemWidth,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VipGradeInfoPage()),
            );
          },
          child: WreathItem(label: label),
        ),
      )).toList(),
    );
  }
}

class WreathItem extends StatelessWidget {
  final String label;

  const WreathItem({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70, // Fix: Explicit height to prevent layout instability
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Golden Gradient Text
          FittedBox(
            fit: BoxFit.scaleDown,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFFFDE68A), // Light Gold
                Color(0xFFD97706), // Amber
                Color(0xFF92400E), // Bronze
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Colors.white, // Masked
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        const SizedBox(height: 6),

        // Stars
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) => 
              const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14)
          ),
        ),
      ],
    ),
   );
  }
}
