import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';

class PremiumDonutChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isLoading;

  const PremiumDonutChart({
    super.key,
    required this.data,
    this.isLoading = false,
  });

  @override
  State<PremiumDonutChart> createState() => _PremiumDonutChartState();
}

class _PremiumDonutChartState extends State<PremiumDonutChart> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart);
    
    _scoreAnimation = Tween<double>(begin: 0, end: _calculateTotalScore()).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutExpo)
    );

    if (!widget.isLoading) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(PremiumDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading && !widget.isLoading) {
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _calculateTotalScore() {
    if (widget.data.containsKey('total_score')) {
       return (widget.data['total_score'] as num).toDouble();
    }
    return 99.0; // Mock default
  }

  // Model Construction
  List<_ChartData> _getChartData() {
     if (widget.data['category_breakdown'] == null) {
       // Mock for testing
       return [
         _ChartData('การงาน', 25, 25, 0),
         _ChartData('การเงิน', 25, 25, 0),
         _ChartData('ความรัก', 25, 25, 0),
         _ChartData('สุขภาพ', 25, 25, 0),
       ];
     }

     final raw = widget.data['category_breakdown'] as Map<String, dynamic>;
     final List<_ChartData> list = [];
     
     raw.forEach((k, v) {
        if (k == 'N/A') return;
        double total = 0;
        double good = 0;
        double bad = 0;
        
        if (v is num) {
           total = v.toDouble();
           good = total; 
        } else if (v is Map) {
           total = (v['total'] as num?)?.toDouble() ?? 0;
           good = (v['good'] as num?)?.toDouble() ?? 0;
           bad = (v['bad'] as num?)?.toDouble() ?? 0;
        }
        
        list.add(_ChartData(k, total, good, bad));
     });
     
     return list;
  }
  
  Map<String, double> _getPainterData(List<_ChartData> data) {
    Map<String, double> map = {};
    for (var d in data) map[d.category] = d.totalPercent;
    return map;
  }

  List<Color> _getCategoryGradient(String category) {
    switch (category) {
      case 'การงาน': return [const Color(0xFF3B82F6), const Color(0xFF60A5FA)]; // Blue
      case 'การเงิน': return [const Color(0xFFD97706), const Color(0xFFFCD34D)]; // Gold
      case 'ความรัก': return [const Color(0xFFDB2777), const Color(0xFFF472B6)]; // Pink
      case 'สุขภาพ': return [const Color(0xFF059669), const Color(0xFF34D399)]; // Emerald
      default: return [Colors.grey, Colors.grey.shade400];
    }
  }
  
  Color _getCategoryColor(String category) {
     return _getCategoryGradient(category)[0];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildSkeleton();
    }

    final chartData = _getChartData();
    final percentages = _getPainterData(chartData);
    
    // We can recalculate end of animation if data changed drastically, but simplify for now.

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Chart
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(220, 220),
                      painter: _DonutChartPainter(
                        percentages: percentages,
                        progress: _animation.value,
                        getCategoryGradient: _getCategoryGradient,
                      ),
                    );
                  },
                ),
                
                // Center Text
                Container(
                   width: 156,
                   height: 156,
                   decoration: BoxDecoration(
                     color: Colors.white,
                     shape: BoxShape.circle,
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withOpacity(0.15),
                         blurRadius: 15,
                         offset: const Offset(0, 4),
                       )
                     ]
                   ),
                   child: AnimatedBuilder(
                     animation: _scoreAnimation,
                     builder: (context, child) {
                       return _buildCenterText(_scoreAnimation.value);
                     }
                   ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Legend
          _buildLegend(chartData),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: [
        const _PulseSkeleton(width: 220, height: 220, borderRadius: 110),
        const SizedBox(height: 24),
        const _PulseSkeleton(width: double.infinity, height: 100, borderRadius: 16),
      ],
    );
  }

  Widget _buildCenterText(double score) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'คะแนนรวม',
          style: GoogleFonts.kanit(
            fontSize: 14,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Color(0xFFB45309), // Dark
                Color(0xFFFFD700), // Gold
                Color(0xFFF59E0B), // Amber
                Color(0xFFFFD700), // Gold
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: Text(
            '${score.toInt()}%',
            style: GoogleFonts.kanit(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(List<_ChartData> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
             children: [
                Expanded(flex: 2, child: Text('หมวดหมู่', style: GoogleFonts.kanit(color: Colors.grey[500], fontSize: 13))),
                Expanded(child: Text('% รวม', textAlign: TextAlign.right, style: GoogleFonts.kanit(color: Colors.grey[500], fontSize: 13))),
                Expanded(child: Text('ค่า', textAlign: TextAlign.right, style: GoogleFonts.kanit(color: Colors.grey[500], fontSize: 13))),
             ],
          ),
          const SizedBox(height: 12),
          
          ...data.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _getCategoryGradient(item.category)),
                    shape: BoxShape.circle
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: Text(item.category, style: GoogleFonts.kanit(fontWeight: FontWeight.w600, fontSize: 15))),
                
                Expanded(child: Text('${item.totalPercent.toInt()}%', textAlign: TextAlign.right, style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)))),
                
                Expanded(child: Text('${item.goodPercent.toInt()}/${item.badPercent.toInt()}', textAlign: TextAlign.right, style: GoogleFonts.kanit(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[400]))),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}

// --- Top Level Classes ---

class _ChartData {
  final String category;
  final double totalPercent;
  final double goodPercent;
  final double badPercent;
  _ChartData(this.category, this.totalPercent, this.goodPercent, this.badPercent);
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, double> percentages;
  final double progress;
  final List<Color> Function(String) getCategoryGradient;

  _DonutChartPainter({required this.percentages, required this.progress, required this.getCategoryGradient});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 36.0; 
    
    final trackPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth/2, trackPaint);

    double total = percentages.values.fold(0, (a, b) => a + b);
    if (total == 0) total = 100;

    double startAngle = -math.pi / 2;

    for (var entry in percentages.entries) {
      if (entry.value <= 0) continue;

      final pct = entry.value; 
      final sweepAngle = (pct / 100) * 2 * math.pi * progress;
      
      final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth/2);
      final colors = getCategoryGradient(entry.key);
      
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      
      paint.shader = SweepGradient(
        center: Alignment.center,
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: colors,
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      if (percentages.length > 1) {
         final gapPaint = Paint()
           ..color = Colors.white
           ..style = PaintingStyle.stroke
           ..strokeWidth = strokeWidth + 2 
           ..strokeCap = StrokeCap.butt;
         
         const gapSizeRad = 0.03; 
         canvas.drawArc(rect, startAngle + sweepAngle - gapSizeRad, gapSizeRad, false, gapPaint);
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PulseSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _PulseSkeleton({required this.width, required this.height, required this.borderRadius});

  @override
  State<_PulseSkeleton> createState() => _PulseSkeletonState();
}

class _PulseSkeletonState extends State<_PulseSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorExt;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _colorExt = ColorTween(begin: Colors.grey[200], end: Colors.grey[300]).animate(_controller);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorExt,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _colorExt.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
