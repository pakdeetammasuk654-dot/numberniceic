import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LuckyNumberCard extends StatelessWidget {
  final String phoneNumber;
  final int sum; // e.g. 45
  final bool isVip;
  final List<String> keywords;
  final VoidCallback? onBuy;
  final VoidCallback? onAnalyze;
  final VoidCallback? onClose;

  final String? buyButtonLabel;
  final String? analyzeButtonLabel;
  final Color? analyzeButtonColor;
  final Color? analyzeButtonBorderColor;

  const LuckyNumberCard({
    super.key,
    required this.phoneNumber,
    required this.sum,
    this.isVip = false,
    this.keywords = const [],
    this.onBuy,
    this.onAnalyze,
    this.onClose,
    this.buyButtonLabel,
    this.analyzeButtonLabel,
    this.analyzeButtonColor,
    this.analyzeButtonBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEF), // Light yellow background
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Keywords
                Text(
                  keywords.join(', '),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    color: const Color(0xFF5D5D5D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFD4AF37), // Metallic Gold
                        Color(0xFFFFD700), // Yellow Gold
                        Color(0xFFB8860B), // Dark Goldenrod
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Text(
                      _formatPhoneNumber(phoneNumber),
                      style: GoogleFonts.kanit(
                        fontSize: 40, // Reduced from 48
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // Required for ShaderMask
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Badges Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Sum Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0B2), // Light Orange/Cream
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ผลรวม $sum',
                        style: GoogleFonts.kanit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8D6E63), // Brownish
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // VIP Badge
                    if (isVip)
                      Row(
                        children: [
                          Text(
                            'เบอร์ VIP',
                            style: GoogleFonts.kanit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF795548), // Brown
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Use text emoji for closer match to design, or keep Icon but colored differently
                          const Icon(Icons.auto_awesome, size: 20, color: Color(0xFFD4AF37)), 
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Dashed Line
                CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: DashedLinePainter(),
                ),
                const SizedBox(height: 20),

                // Buttons Column
                Column(
                  children: [
                    Row(
                      children: [
                        // Buy Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onBuy,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981), // Vivid Green (Success)
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_cart_outlined, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  buyButtonLabel ?? 'ซื้อเลย',
                                  style: GoogleFonts.kanit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Close Button
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE), // Light Red
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFFE57373)),
                            onPressed: onClose,
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Analyze Button Row
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onAnalyze,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: analyzeButtonColor ?? const Color(0xFF2962FF), // Default Blue
                          side: BorderSide(color: analyzeButtonBorderColor ?? const Color(0xFFBBDEFB), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if ((analyzeButtonLabel ?? '').contains('ลบ'))
                              Icon(Icons.delete_outline, size: 20, color: analyzeButtonColor)
                            else
                              const Icon(Icons.search, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              analyzeButtonLabel ?? 'วิเคราะห์เบอร์นี้',
                              style: GoogleFonts.kanit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPhoneNumber(String number) {
    if (number.length == 10) {
      return '${number.substring(0, 3)}${number.substring(3, 6)}${number.substring(6)}';
    }
    return number;
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 5, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1.5;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
