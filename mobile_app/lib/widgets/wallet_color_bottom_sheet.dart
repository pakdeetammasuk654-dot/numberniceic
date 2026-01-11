import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WalletColorBottomSheet extends StatelessWidget {
  final List<String> colors;

  const WalletColorBottomSheet({super.key, required this.colors});

  static Future<void> show(BuildContext context, List<String> colors) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => WalletColorBottomSheet(colors: colors),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, -5),
          )
        ],
        border: Border(
           top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Icon with Premium Gold Gradient & Glow
          Container(
            padding: const EdgeInsets.all(3), // Border gap
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFBF953F), Color(0xFFFCF6BA), Color(0xFFB38728), Color(0xFFFBF5B7), Color(0xFFAA771C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                   color: Colors.amber.withOpacity(0.4),
                   blurRadius: 20,
                   spreadRadius: 2,
                )
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E), // Inner dark circle
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFFFFD700), // Gold Icon
                size: 56,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'สีกระเป๋ามงคลของคุณ',
            style: GoogleFonts.kanit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFCF6BA), // Light Gold text
              shadows: [
                 Shadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'พลังแห่งสีสันที่ส่งเสริมดวงชะตาของคุณ\nจะช่วยดึงดูดโชคลาภ ความมั่งคั่ง\nและความสำเร็จสู่กระเป๋าของคุณในทุกๆ วัน',
            textAlign: TextAlign.center,
            style: GoogleFonts.kanit(
              fontSize: 15,
              color: Colors.white70,
              height: 1.6,
              fontWeight: FontWeight.w300,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Color List
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 20,
            children: colors.map((hex) => _buildColorCircle(hex)).toList(),
          ),
          
          const SizedBox(height: 48),
          
          // Premium Gold Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFBF953F), Color(0xFFFCF6BA), Color(0xFFB38728), Color(0xFFFBF5B7), Color(0xFFAA771C)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFAA771C).withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'รับทราบ',
                style: GoogleFonts.kanit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3E2723), // Dark Brown text for contrast on gold
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildColorCircle(String hex) {
    // Basic hex parsing (e.g. #FF0000 or FF0000)
    String cleanHex = hex.trim().toUpperCase().replaceAll('#', '');
    print('🎨 Parsing Color: Input="$hex", Clean="$cleanHex"');
    
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    
    Color color;
    try {
      color = Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      print('❌ Error parsing color: $e');
      color = Colors.grey;
    }

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 boxShadow: [
                    BoxShadow(
                       color: color.withOpacity(0.6),
                       blurRadius: 15,
                       spreadRadius: 2,
                    ),
                 ],
              ),
            ),
            // Border Ring
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                gradient: LinearGradient(
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                   colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.0)],
                ),
              ),
            ),
            // Actual Color
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                     color.withOpacity(0.8),
                     color,
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
