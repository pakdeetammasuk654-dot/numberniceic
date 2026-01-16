import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BackgroundPatternPainter extends CustomPainter {
  final Color? color;
  final double opacity;

  BackgroundPatternPainter({this.color, this.opacity = 0.25});

  @override
  void paint(Canvas canvas, Size size) {
    // Luxury Tan/Gold color for the monogram symbols
    final symbolColor = (color ?? const Color(0xFFA67C52)).withOpacity(opacity); 
    
    final paint = Paint()
      ..color = symbolColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Grid Spacing (Reduced for denser pattern)
    const double spacingX = 45.0;
    const double spacingY = 45.0;
    
    for (double y = -spacingY; y < size.height + spacingY; y += spacingY) {
      final bool isOddRow = ((y + spacingY) / spacingY).round() % 2 != 0;
      final double offsetX = isOddRow ? spacingX / 2 : 0;
      
      for (double x = -spacingX; x < size.width + spacingX; x += spacingX) {
        final double posX = x + offsetX;
        
        // Alternate symbols based on grid position
        int symbolType = (((x / spacingX).floor() + (y / spacingY).floor())).abs() % 3;
        
        if (symbolType == 0) {
          // 1. Stylized "N" Logo
          textPainter.text = TextSpan(
            text: 'N',
            style: GoogleFonts.philosopher( 
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: symbolColor,
            ),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(posX - textPainter.width / 2, y - textPainter.height / 2));
        } else if (symbolType == 1) {
          // 2. Diamond Star
          _drawDiamondStar(canvas, Offset(posX, y), 8, paint);
        } else {
          // 3. Flower/Circle Symbol
          _drawMonogramCircle(canvas, Offset(posX, y), 7, paint);
        }
      }
    }
  }

  void _drawDiamondStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final Path path = Path();
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(center.dx + radius * 0.2, center.dy - radius * 0.2, center.dx + radius, center.dy);
    path.quadraticBezierTo(center.dx + radius * 0.2, center.dy + radius * 0.2, center.dx, center.dy + radius);
    path.quadraticBezierTo(center.dx - radius * 0.2, center.dy + radius * 0.2, center.dx - radius, center.dy);
    path.quadraticBezierTo(center.dx - radius * 0.2, center.dy - radius * 0.2, center.dx, center.dy - radius);
    canvas.drawPath(path, paint);
    canvas.drawCircle(center, 2, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
  }

  void _drawMonogramCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    for (int i = 0; i < 4; i++) {
      double angle = i * math.pi / 2;
      canvas.drawCircle(
        Offset(center.dx + (radius * 0.5) * math.cos(angle), center.dy + (radius * 0.5) * math.sin(angle)),
        radius * 0.3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
