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
    // Determine screen width to adjust layout if needed
    final width = MediaQuery.of(context).size.width;
    // Aim for 3 columns on typical phones, 2 on very small
    int crossAxisCount = width > 350 ? 3 : 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 2.2, // Taller (flatter) cells
          crossAxisSpacing: 10,
          mainAxisSpacing: 4, 
        ),
        itemCount: labels.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VipGradeInfoPage()),
              );
            },
            child: WreathItem(label: labels[index]),
          );
        },
      ),
    );
  }
}

class WreathItem extends StatelessWidget {
  final String label;

  const WreathItem({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60, 
      child: Stack(
        alignment: Alignment.center,
        children: [
            // Side Wreaths images if you had them, but for now just text and stars as per previous code
            // Actually previous code didn't have images, just text and stars.
            // Wait, the web version has images. The mobile version code I viewed only had text and stars.
            // I should respect the previous design.

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               // Golden Gradient Text
              ShaderMask(
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
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
              
              const SizedBox(height: 4),

              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) => 
                   const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14)
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
