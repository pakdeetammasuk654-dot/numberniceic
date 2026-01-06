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
  final Color? themeColor; // New: Color from Category

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
    this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    // Default theme color if not provided
    final primaryColor = themeColor ?? const Color(0xFFD4AF37);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEF), // Light yellow background
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
        clipBehavior: Clip.none, // Allow overflow
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Keywords
                Text(
                  keywords.join(', '),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    color: const Color(0xFF5D5D5D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // Phone Number (Golden Gradient)
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
                        fontSize: 36, 
                        fontWeight: FontWeight.w900,
                        color: Colors.white, // Required for ShaderMask
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Badges Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Sum Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15), // Light Tint
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ผลรวม $sum',
                        style: GoogleFonts.kanit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryColor.withOpacity(0.8), // Darker Tint
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dashed Line
                CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: DashedLinePainter(),
                ),
                const SizedBox(height: 16),

                // Buttons Row
                Row(
                  children: [
                    // Button Group (Buy + Analyze)
                    Expanded(
                      child: Row(
                        children: [
                          // Buy Button
                          Expanded(
                            flex: 3,
                                child: ElevatedButton(
                                onPressed: () {
                                  print('🔘 LuckyNumberCard Button Pressed');
                                  if (onBuy != null) onBuy!();
                                },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981), 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shopping_cart_outlined, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    buyButtonLabel ?? 'ซื้อเลย',
                                    style: GoogleFonts.kanit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Analyze Button
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              onPressed: onAnalyze,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: analyzeButtonColor ?? const Color(0xFF64748B),
                                side: BorderSide(color: analyzeButtonBorderColor ?? const Color(0xFFCBD5E1), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.analytics_outlined, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    'วิเคราะห์', 
                                    style: GoogleFonts.kanit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Close Button (Pushed out)
                    Transform.translate(
                      offset: const Offset(12, 0), // Push out to the right slightly
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12), // Fixed duplication
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFE57373)),
                          onPressed: onClose,
                          padding: EdgeInsets.zero,
                          iconSize: 20,
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
    if (number.length >= 10) {
      // 099-999-9999
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
