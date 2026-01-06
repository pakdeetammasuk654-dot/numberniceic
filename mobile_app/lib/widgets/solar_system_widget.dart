import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class SolarSystemWidget extends StatefulWidget {
  final Map<String, dynamic>? sumPair;
  final List<dynamic>? mainPairs;
  final List<dynamic>? hiddenPairs;

  const SolarSystemWidget({
    super.key,
    required this.sumPair,
    required this.mainPairs,
    required this.hiddenPairs,
  });

  @override
  State<SolarSystemWidget> createState() => _SolarSystemWidgetState();
}

class _SolarSystemWidgetState extends State<SolarSystemWidget> with TickerProviderStateMixin {
  late AnimationController _innerController;
  late AnimationController _outerController;

  @override
  void initState() {
    super.initState();
    _innerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _outerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _innerController.dispose();
    _outerController.dispose();
    super.dispose();
  }

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    try {
      String clean = hex.replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      return Color(int.parse(clean, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safety check
    if (widget.sumPair == null) return const SizedBox.shrink();

    final sumNumber = widget.sumPair!['pair']?.toString() ?? '?';
    // Sum color usually fixed to Gold/Yellow for the Sun in this design, 
    // or use the data color? The image shows yellow. 
    // The web version uses "sun-dead" class for bad suns. 
    // For phone numbers, let's use a nice Gold gradient for the sun background.

    return Column(
      children: [
        Text(
          "วงใน: คู่เลขหลัก | วงนอก: คู่เลขแฝง",
          style: GoogleFonts.kanit(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 300,
          width: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Orbits (Painted)
              CustomPaint(
                size: const Size(300, 300),
                painter: OrbitsPainter(),
              ),

              // Sun (Center)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFBC02D)],
                    stops: [0.6, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                      blurRadius: 30, 
                      spreadRadius: 5,
                    )
                  ],
                  // border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 54, 
                  height: 54,
                  decoration: BoxDecoration(
                    color: _parseColor(widget.sumPair!['meaning']?['color']?.toString()),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                       BoxShadow(
                         color: Colors.black.withOpacity(0.2), 
                         blurRadius: 4,
                         offset: const Offset(0, 2),
                       )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    sumNumber,
                    style: GoogleFonts.kanit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Inner Planets (Main Pairs)
              if (widget.mainPairs != null)
                AnimatedBuilder(
                  animation: _innerController,
                  builder: (context, child) {
                    return Stack(
                      children: List.generate(widget.mainPairs!.length, (index) {
                        final item = widget.mainPairs![index];
                        final pairNum = item['pair']?.toString() ?? '';
                        final colorHex = item['meaning']?['color']?.toString();
                        final color = _parseColor(colorHex);
                        
                        // Calculate position
                        // Radius for inner orbit = ? (OrbitPainter will define it, let's say 90)
                        final double orbitRadius = 85.0;
                        final int count = widget.mainPairs!.length;
                        final double angleStep = 2 * math.pi / count;
                        // Add rotation from controller
                        final double currentAngle = (angleStep * index) + (_innerController.value * 2 * math.pi);

                        return Positioned(
                          left: 150 + orbitRadius * math.cos(currentAngle) - 18, // 150 is center, 18 is half size
                          top: 150 + orbitRadius * math.sin(currentAngle) - 18,
                          child: _buildPlanet(pairNum, color),
                        );
                      }),
                    );
                  },
                ),

              // Outer Planets (Hidden Pairs)
              if (widget.hiddenPairs != null)
                AnimatedBuilder(
                  animation: _outerController,
                  builder: (context, child) {
                    return Stack(
                      children: List.generate(widget.hiddenPairs!.length, (index) {
                        final item = widget.hiddenPairs![index];
                        final pairNum = item['pair']?.toString() ?? '';
                        final colorHex = item['meaning']?['color']?.toString();
                        final color = _parseColor(colorHex);
                        
                        // Calculate position
                        // Radius for outer orbit = ? (OrbitPainter will define it, let's say 135)
                        final double orbitRadius = 135.0;
                        final int count = widget.hiddenPairs!.length;
                        final double angleStep = 2 * math.pi / count;
                        // Add rotation from controller (slower)
                        final double currentAngle = (angleStep * index) + (_outerController.value * 2 * math.pi);

                        return Positioned(
                          left: 150 + orbitRadius * math.cos(currentAngle) - 18,
                          top: 150 + orbitRadius * math.sin(currentAngle) - 18,
                          child: _buildPlanet(pairNum, color),
                        );
                      }),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanet(String number, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: GoogleFonts.kanit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class OrbitsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFFFCC80).withOpacity(0.5) // Light Orange/Gold dashed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Inner Orbit Radius = 85
    _drawDashedCircle(canvas, center, 85, paint);

    // Outer Orbit Radius = 135
    paint.color = const Color(0xFFFFCC80).withOpacity(0.3);
    _drawDashedCircle(canvas, center, 135, paint);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const double dashWidth = 4;
    const double dashSpace = 4;
    double startAngle = 0;
    final double circumference = 2 * math.pi * radius;
    final int dashCount = (circumference / (dashWidth + dashSpace)).floor();
    final double angleStep = (2 * math.pi) / dashCount;

    for (int i = 0; i < dashCount; i++) {
        // Draw small arc for dash
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          angleStep * 0.5, // Half step for dash
          false,
          paint,
        );
        startAngle += angleStep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
