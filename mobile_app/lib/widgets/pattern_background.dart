import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatternBackground extends StatelessWidget {
  final Widget? child;
  final bool isDark;

  const PatternBackground({
    super.key, 
    this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            foregroundPainter: _PatternPainter(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF1F5F9),
                gradient: isDark ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1A2E), // Dark Navy
                    Color(0xFF151525), // Slightly darker
                    Color(0xFF1A1A2E),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ) : null,
              ),
            ),
          ),
        ),
        if (child != null) 
          Positioned.fill(child: child!),
      ],
    );
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
      
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    const double spacing = 60.0; // Denser
    const double offset = 30.0;

    for (double y = 0; y < size.height + spacing; y += spacing) {
      for (double x = 0; x < size.width + spacing; x += spacing) {
        
        // Determine type based on grid position
        int type = ((x ~/ spacing) + (y ~/ spacing)) % 4;
        
        double drawX = x;
        double drawY = y;
        
        // Stagger every other row
        if ((y / spacing).floor() % 2 == 1) {
           drawX += offset;
        }

        switch (type) {
          case 0: // Four-pointed star (Sparkle)
             _drawSparkle(canvas, drawX, drawY, 12, fillPaint);
             break;
          case 1: // Circle with dots (Flower-ish)
             _drawFlower(canvas, drawX, drawY, 10, paint);
             break;
          case 2: // Letter N
             _drawText(canvas, drawX, drawY, 'N', textPainter);
             break;
          case 3: // Another Sparkle or Circle
             _drawSparkle(canvas, drawX, drawY, 8, fillPaint); // Smaller sparkle
             break;
        }
      }
    }
  }

  void _drawSparkle(Canvas canvas, double x, double y, double radius, Paint paint) {
    final path = Path();
    path.moveTo(x, y - radius);
    path.quadraticBezierTo(x, y, x + radius, y);
    path.quadraticBezierTo(x, y, x, y + radius);
    path.quadraticBezierTo(x, y, x - radius, y);
    path.quadraticBezierTo(x, y, x, y - radius);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawFlower(Canvas canvas, double x, double y, double radius, Paint paint) {
    // Outer circle
    canvas.drawCircle(Offset(x, y), radius, paint);
    // Inner dots
    final dotPaint = Paint()..color = paint.color..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x - 3, y - 3), 1.5, dotPaint);
    canvas.drawCircle(Offset(x + 3, y - 3), 1.5, dotPaint);
    canvas.drawCircle(Offset(x - 3, y + 3), 1.5, dotPaint);
    canvas.drawCircle(Offset(x + 3, y + 3), 1.5, dotPaint);
  }

  void _drawText(Canvas canvas, double x, double y, String text, TextPainter tp) {
    tp.text = TextSpan(
      text: text,
      style: GoogleFonts.cinzel( // A nice serif font looks like the 'N'
        fontSize: 20,
        color: color.withOpacity(color.opacity * 1.5), // Slightly more visible
        fontWeight: FontWeight.bold,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
