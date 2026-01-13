import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/name_character.dart';
import 'dart:math' as math;

class SolarSystemWidget extends StatefulWidget {
  final Map<String, dynamic>? sumPair;
  final List<dynamic>? mainPairs;
  final List<dynamic>? hiddenPairs;
  final String? title;
  final List<NameCharacter>? displayName;
  final bool isDead;

  const SolarSystemWidget({
    super.key,
    required this.sumPair,
    required this.mainPairs,
    required this.hiddenPairs,
    this.title,
    this.displayName,
    this.isDead = false,
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
    if (widget.sumPair == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double centerX = width / 2;
        final double centerY = height / 2;
        final double minDim = math.min(width, height);
        
        // Use fixed reference size (220) for orbit sizing to allow container expansion without scaling orbits
        const double refSize = 220.0;
        final double innerRadius = refSize * 0.35; 
        final double outerRadius = refSize * 0.48;  

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none, // Allow planets to orbit outside container
            children: [
              // Orbits (Painted)
              CustomPaint(
                size: Size(width, height),
                painter: OrbitsPainter(innerRadius: innerRadius, outerRadius: outerRadius),
              ),

              // Sun (Center)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.isDead 
                    ? const RadialGradient(
                        colors: [Color(0xFF757575), Color(0xFF212121)],
                        stops: [0.6, 1.0],
                      )
                    : const RadialGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFBC02D)],
                        stops: [0.6, 1.0],
                      ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isDead ? Colors.black : const Color(0xFFFFD700)).withOpacity(0.5),
                      blurRadius: 30, 
                      spreadRadius: 5,
                    )
                  ],
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 80, 
                  height: 80,
                  alignment: Alignment.center,
                  child: (widget.displayName != null && widget.displayName!.isNotEmpty)
                    ? Wrap(
                        alignment: WrapAlignment.center,
                        children: widget.displayName!.map((dc) => Text(
                          dc.char,
                          style: GoogleFonts.kanit(
                            fontSize: 16, // Increased slightly from 12
                            fontWeight: FontWeight.w900,
                            color: dc.isBad ? const Color(0xFFFF1744) : (widget.isDead ? Colors.white70 : const Color(0xFF4A3400)),
                            height: 1.0,
                          ),
                        )).toList(),
                      )
                    : Text(
                        widget.title ?? '',
                        style: GoogleFonts.kanit(
                          fontSize: 16, // Increased slightly from 12
                          fontWeight: FontWeight.w900,
                          color: widget.isDead ? Colors.white70 : const Color(0xFF4A3400),
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                ),
              ),

              // Inner Orbit (Animated) - Clockwise (+)
              if (widget.mainPairs != null)
                AnimatedBuilder(
                  animation: _innerController,
                  builder: (context, child) {
                    return Stack(
                      children: List.generate(widget.mainPairs!.length, (index) {
                        final item = widget.mainPairs![index];
                        final pairNum = item['pair']?.toString() ?? item['pair_number']?.toString() ?? '';
                        bool isBad = false;
                        if (item['meaning'] != null) {
                           isBad = item['meaning']['is_bad'] == true;
                        }

                        // Calculate position - Clockwise
                        double angle = (2 * math.pi * index / widget.mainPairs!.length) + (2 * math.pi * _innerController.value);

                        return Positioned(
                          left: centerX + innerRadius * math.cos(angle) - 14,
                          top: centerY + innerRadius * math.sin(angle) - 14,
                          child: _buildPlanet(pairNum, isBad ? const Color(0xFFEF4444) : const Color(0xFF10B981), isBad: isBad),
                        );
                      }),
                    );
                  },
                ),

              // Outer Orbit (Animated) - Changed to Clockwise (+)
              if (widget.hiddenPairs != null)
                AnimatedBuilder(
                  animation: _outerController,
                  builder: (context, child) {
                    return Stack(
                      children: List.generate(widget.hiddenPairs!.length, (index) {
                        final item = widget.hiddenPairs![index];
                        final pairNum = item['pair']?.toString() ?? item['pair_number']?.toString() ?? '';
                        bool isBad = false;
                        if (item['meaning'] != null) {
                           isBad = item['meaning']['is_bad'] == true;
                        }

                        // Calculate position - Clockwise (+)
                        double angle = (2 * math.pi * index / widget.hiddenPairs!.length) + (2 * math.pi * _outerController.value);

                        return Positioned(
                          left: centerX + outerRadius * math.cos(angle) - 14,
                          top: centerY + outerRadius * math.sin(angle) - 14,
                          child: _buildPlanet(pairNum, isBad ? const Color(0xFFEF4444) : const Color(0xFF10B981), isBad: isBad),
                        );
                      }),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanet(String number, Color color, {required bool isBad}) {
    // Exact colors from image
    final planetColor = isBad ? const Color(0xFFFF1744) : const Color(0xFF00C853);
    
    return Container(
      width: 32, 
      height: 32,
      decoration: BoxDecoration(
        color: planetColor,
        shape: BoxShape.circle,
        // Removed border as requested
        boxShadow: [
          BoxShadow(
            color: planetColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: GoogleFonts.kanit(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

class OrbitsPainter extends CustomPainter {
  final double innerRadius;
  final double outerRadius;

  OrbitsPainter({required this.innerRadius, required this.outerRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFFFCC80).withOpacity(0.5);

    // Inner orbit
    _drawDashedCircle(canvas, center, innerRadius, paint);
    // Outer orbit
    _drawDashedCircle(canvas, center, outerRadius, paint);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const double dashWidth = 5;
    const double dashSpace = 5;
    double circumference = 2 * math.pi * radius;
    int dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      double startAngle = (i * (dashWidth + dashSpace)) / radius;
      double sweepAngle = dashWidth / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant OrbitsPainter oldDelegate) {
    return oldDelegate.innerRadius != innerRadius || oldDelegate.outerRadius != outerRadius;
  }
}
