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
  AnimationController? _shineController; // Fix: Nullable to prevent LateInitError on hot reload

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

    _initShineController();
  }

  void _initShineController() {
     _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    )..repeat();
  }

  @override
  void dispose() {
    _innerController.dispose();
    _outerController.dispose();
    _shineController?.dispose();
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

  bool _isBadColor(String? color) {
    if (color == null) return false;
    final c = color.replaceAll('#', '').toUpperCase(); // Returns RRGGBB
    // Specific Red shades from backend
    const badColors = [
      'D32F2F', 'F44336', 'FF1744', 'B71C1C', 'EF5350', 'E53935', // Reds
      'C62828', 'D50000', 'FF5252', 'FF8A80', // More Reds
    ]; 
    return badColors.any((bc) => c.contains(bc));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sumPair == null) return const SizedBox.shrink();
    
    // Ensure controller exists (Hot Reload Fix)
    if (_shineController == null) _initShineController();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Expands size to accommodate larger Sun/Text (75% of width)
        final double orbitBaseSize = width * 0.75;
        final double height = constraints.maxHeight.isFinite 
            ? constraints.maxHeight 
            : orbitBaseSize + 20.0; 
            
        final double centerX = width / 2;
        final double centerY = height / 2;
        final double minDim = orbitBaseSize; 
        
        final double refSize = minDim * 0.95;
        // Adjusted Radii for Larger Sun
        final double innerRadius = refSize * 0.38; // Pushed out slightly
        final double outerRadius = refSize * 0.50; // Outer edge

        // Determine center text (Title or Sum Pair)
        String centerText = widget.title ?? '';
        if (centerText.isEmpty && widget.sumPair != null) {
          centerText = widget.sumPair!['pair']?.toString() ?? 
                      widget.sumPair!['pair_number']?.toString() ?? '';
        }

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none, 
            children: [
              // Orbits (Painted)
              CustomPaint(
                size: Size(width, height),
                painter: OrbitsPainter(innerRadius: innerRadius, outerRadius: outerRadius),
              ),

              // Sun (Center)
              AnimatedBuilder(
                animation: _shineController!, // Use fast controller
                builder: (context, child) {
                   // Logic Check: 
                   // If backend says is_bad OR color is Red -> Show Red Sun
                   // Else -> Show Gold Sun
                   bool isBadSum = false; 
                   if (widget.sumPair != null && widget.sumPair!['meaning'] != null) {
                      final meaning = widget.sumPair!['meaning'];
                      if (meaning['is_bad'] == true) {
                          isBadSum = true;
                      } else {
                          // Double check color just in case
                          isBadSum = _isBadColor(meaning['color']);
                      }
                   }
                   
                   bool isGoldSun = !isBadSum;
                   
                   // Determine Sun Style based on Sum Quality
                   BoxDecoration decoration;
                   TextStyle textStyle;
                   
                   if (widget.isDead) { // Exernally forced dead state
                      decoration = BoxDecoration(
                         color: const Color(0xFF424242),
                         shape: BoxShape.circle,
                         boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)
                         ]
                      );
                      textStyle = GoogleFonts.kanit(
                            fontSize: refSize * 0.18, 
                            fontWeight: FontWeight.w900,
                            color: Colors.white70,
                            height: 1.0,
                      );
                   } else if (isBadSum) { 
                      // BAD SUM -> RED SUN (Dead Star)
                      decoration = BoxDecoration(
                        color: const Color(0xFFD32F2F), 
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                            colors: [Color(0xFFEF5350), Color(0xFFB71C1C)], // Light Red to Dark Red
                            stops: [0.2, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB71C1C).withOpacity(0.8), // Red Glow
                            blurRadius: 20, 
                            spreadRadius: 2,
                          )
                        ],
                      );
                      textStyle = GoogleFonts.kanit(
                            fontSize: refSize * 0.18, 
                            fontWeight: FontWeight.w900,
                            color: Colors.white, // White text on Red
                            height: 1.0,
                      );
                   } else {
                      // GOLD SUN (Soft & Warm) - Reduced Glare to minimum
                      decoration = BoxDecoration(
                            color: const Color(0xFFFFFDE7), // Very soft Cream
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                                colors: [Color(0xFFFFFDE7), Color(0xFFFFECB3)], // Cream to Soft Amber
                                stops: [0.5, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.2), // Very subtle Gold Glow
                                blurRadius: 15, 
                                spreadRadius: 1, 
                              )
                            ],
                          );
                      textStyle = GoogleFonts.kanit(
                            fontSize: refSize * 0.14, 
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF8D6E63), // Brown/Earth Tone for text (Softer than Gold/Orange)
                            height: 1.0,
                      );
                   }
                   
                   // Check for Kalakini (Bad Characters) in the name
                   bool hasBadChars = widget.displayName?.any((dc) => dc.isBad) ?? false;

                   // Prepare Text Widget
                   Widget textWidget;
                   if (widget.displayName != null && widget.displayName!.isNotEmpty) {
                      textWidget = Wrap(
                        alignment: WrapAlignment.center,
                        children: widget.displayName!.map((dc) {
                          // Determine character color
                          Color charColor;
                          if (hasBadChars) {
                             // If Kalakini exists: Red for bad, Black for good
                             charColor = dc.isBad ? const Color(0xFFD32F2F) : Colors.black;
                          } else {
                             // Otherwise follow the base style (Brown or White)
                             charColor = textStyle.color!;
                          }

                          return Text(
                            dc.char,
                            style: textStyle.copyWith(
                              fontSize: refSize * 0.08, // Reduced Name Size
                              color: charColor, // Apply determined color
                            ), 
                          );
                        }).toList(),
                      );
                   } else {
                      textWidget = Text(centerText, style: textStyle, textAlign: TextAlign.center);
                   }

                   // Apply Golden Shader to TEXT ONLY (if Gold Sun, not dead, AND NO BAD CHARS)
                   // If there are bad chars, we want the Black/Red contrast to be visible, so no shader.
                   if (isGoldSun && !widget.isDead && !hasBadChars) {
                      textWidget = ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: const [
                              Color(0xFFAA771C), // Gold Dark
                              Color(0xFFFDD835), // Gold Light
                              Colors.white,      // Sparkle
                              Color(0xFFFDD835), // Gold Light
                              Color(0xFFAA771C), // Gold Dark
                            ],
                            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                            // Sweep animation
                            begin: Alignment(-2.0 + (_shineController!.value * 4), 0.0),
                            end: Alignment(-0.5 + (_shineController!.value * 4), 0.0),
                            tileMode: TileMode.clamp,
                          ).createShader(bounds);
                        },
                        child: textWidget,
                      );
                   }

                   return Container(
                    width: refSize * 0.55, // Increased from 0.45
                    height: refSize * 0.55,
                    decoration: decoration,
                    alignment: Alignment.center,
                    child: Container(
                      width: refSize * 0.45, // Increased from 0.35
                      height: refSize * 0.45,
                      alignment: Alignment.center,
                      child: textWidget,
                    ),
                  );
                }
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

                        // Parse Color from Backend
                        Color planetColor = const Color(0xFF10B981); // Default Green
                        if (item['meaning']?['color'] != null) {
                           planetColor = _parseColor(item['meaning']['color']);
                        } else if (isBad) {
                           planetColor = const Color(0xFFEF4444); // Fallback Red
                        }

                        return Positioned(
                          left: centerX + innerRadius * math.cos(angle) - 14,
                          top: centerY + innerRadius * math.sin(angle) - 14,
                          child: _buildPlanet(pairNum, planetColor, isBad: isBad),
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

                        // Parse Color from Backend
                        Color planetColor = const Color(0xFF10B981); // Default Green
                        if (item['meaning']?['color'] != null) {
                           planetColor = _parseColor(item['meaning']['color']);
                        } else if (isBad) {
                           planetColor = const Color(0xFFEF4444); // Fallback Red
                        }

                        return Positioned(
                          left: centerX + outerRadius * math.cos(angle) - 14,
                          top: centerY + outerRadius * math.sin(angle) - 14,
                          child: _buildPlanet(pairNum, planetColor, isBad: isBad),
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
    // Use color from backend (or fallback passed in)
    final planetColor = color;
    
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
