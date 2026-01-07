import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/widgets/lucky_number_card.dart';
import 'package:mobile_app/widgets/lucky_number_skeleton.dart';
import 'package:mobile_app/widgets/contact_purchase_modal.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/screens/number_analysis_page.dart';

// --- MAIN WIDGET ---
class CategoryNestedDonut extends StatefulWidget {
  final Map<String, dynamic> categoryBreakdown;
  final int totalPairs;
  final int grandTotalScore;
  final int totalPositiveScore;
  final int totalNegativeScore;

  const CategoryNestedDonut({
    super.key,
    required this.categoryBreakdown,
    required this.totalPairs,
    required this.grandTotalScore,
    required this.totalPositiveScore,
    required this.totalNegativeScore,
  });

  @override
  State<CategoryNestedDonut> createState() => _CategoryNestedDonutState();
}

class _CategoryNestedDonutState extends State<CategoryNestedDonut> with TickerProviderStateMixin {
  final Set<String> _enhancedCategories = {};
  final Map<String, Map<String, dynamic>?> _fetchedLuckyNumbers = {}; 
  final Map<String, int> _categoryIndices = {}; 
  
  AnimationController? _textShineController;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;
  
  // NEW: Chart Wipe Animation
  late AnimationController _chartController;
  late Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _textShineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // Score Count Up
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scoreAnimation = CurvedAnimation(parent: _scoreController, curve: Curves.easeOutExpo);
    
    // Chart Animation (Fan Opening Effect)
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _chartAnimation = CurvedAnimation(parent: _chartController, curve: Curves.easeOutQuint);

    // Safety Delay Start
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
         _scoreController.forward();
         _chartController.forward();
      }
    });
  }

  @override
  void dispose() {
    _textShineController?.dispose();
    _scoreController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _onEnhanceChange(String category, bool isEnhanced) async {
    // Determine if structure changed (Add vs Remove vs Cycle)
    bool structureChanged = false;
    if (!isEnhanced) {
        if (_enhancedCategories.contains(category)) structureChanged = true;
    } else {
        if (!_enhancedCategories.contains(category)) structureChanged = true;
    }

    // CLOSING
    if (!isEnhanced) {
      setState(() {
         _enhancedCategories.remove(category);
         _categoryIndices[category] = 0; 
      });
      if (structureChanged) _chartController.forward(from: 0.0);
      return;
    }

    // OPENING / CYCLING
    int currentIndex = _categoryIndices[category] ?? 0;
    if (_enhancedCategories.contains(category)) {
       currentIndex++; 
    } else {
       currentIndex = 0; 
       structureChanged = true;
    }
    _categoryIndices[category] = currentIndex;

    setState(() {
      _enhancedCategories.add(category);
      // Show loading state by clearing previous number
      _fetchedLuckyNumbers[category] = null; 
    });
    
    // Trigger "Fan Wipe" animation ALWAYS when enhancing/cycling to thrill the user
    _chartController.forward(from: 0.0);

    try {
        final result = await ApiService.getLuckyNumber(category, index: currentIndex);
        if (!mounted) return;
        
        setState(() {
           if (result != null) {
              _fetchedLuckyNumbers[category] = result;
           } else {
              if (currentIndex > 0) {
                 // Loop/Reset logic could go here
              }
           }
        });
    } catch (e) {
      print('Error fetching lucky number: $e');
    }
  }
  
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'การงาน': return const Color(0xFF42A5F5); // Blue
      case 'การเงิน': return const Color(0xFFFFA726); // Orange
      case 'ความรัก': return const Color(0xFFEC407A); // Pink
      case 'สุขภาพ': return const Color(0xFF26A69A); // Teal
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryBreakdown.isEmpty) return const SizedBox.shrink();

    // Prepare chart data
    final List<CategoryData> chartData = [];
    final List<String> categories = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'];

    for (var cat in categories) {
      final data = widget.categoryBreakdown[cat] ?? {};
      
      Map<String, dynamic>? luckyData;
      if (_fetchedLuckyNumbers.containsKey(cat)) {
         luckyData = _fetchedLuckyNumbers[cat];
      } else {
         luckyData = data['suggested_number'];
      }
      
      chartData.add(CategoryData(
        name: cat,
        good: data['good'] ?? 0,
        bad: data['bad'] ?? 0,
        color: _getCategoryColor(cat),
        keywords: List<String>.from(data['keywords'] ?? []),
        suggestedNumber: luckyData,
      ));
    }
    
    // Final Score Logic
     int activeCategories = 0;
     for (var cat in chartData) {
       if (cat.good > 0) activeCategories++;
     }
     bool isEnhanced = _enhancedCategories.isNotEmpty;
     double finalScoreTarget = isEnhanced ? 100.0 : (activeCategories * 25.0);
     if (finalScoreTarget == 0 && activeCategories > 0) finalScoreTarget = 99; 

    return Container(
      color: Colors.white,
      child: Column(
        children: [
        // Chart Section
        SizedBox(
          height: 220,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _chartAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(200, 200),
                      painter: NestedDonutPainter(
                        data: chartData,
                        totalPairs: widget.totalPairs,
                        enhancedCategories: _enhancedCategories,
                        progress: _chartAnimation.value,
                      ),
                    );
                  }
                ),
                // Center Text (Golden)
                Container(
                   width: 136, height: 136,
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
                   child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('คะแนนรวม', style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[500])),
                        
                        // ANIMATED PERCENTAGE
                        AnimatedBuilder(
                          animation: _scoreAnimation,
                          builder: (context, child) {
                            final currentScore = (_scoreAnimation.value * finalScoreTarget).toInt();
                            return ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFB45309), Color(0xFFFFD700), Color(0xFFF59E0B)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight
                              ).createShader(bounds),
                              child: Text(
                                '$currentScore%',
                                style: GoogleFonts.kanit(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)
                              ),
                            );
                          }
                        ),
                      ],
                   ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),

        // Legend Header
        _buildLegendHeader(),
        const Divider(height: 1),

        // Legend List
        Column(
          children: chartData.asMap().entries.map((entry) {
            int idx = entry.key;
            var cat = entry.value;
            bool isEnhanced = _enhancedCategories.contains(cat.name);
            
            // Percentage Logic
            int displayPct = 0;
            int activeCount = 0;
            for (var c in chartData) { if (c.good > 0) activeCount++; }

            if (_enhancedCategories.isEmpty) {
               if (cat.good > 0) displayPct = 25;
            } else {
               double totalUnits = 6.0;
               double activeBaseCost = 1.5;
               double allocated = activeCount * activeBaseCost;
               double remaining = totalUnits - allocated;
               int enhancerCount = _enhancedCategories.length;
               double bonus = enhancerCount > 0 ? remaining / enhancerCount : 0.0;
               
               double weight = 0.0;
               if (cat.good > 0) weight += activeBaseCost;
               if (isEnhanced) weight += bonus;
               if (weight > 0) displayPct = (weight / totalUnits * 100).round();
            }

            return Column(
              children: [
                CategoryLegendRow(
                  key: ValueKey(cat.name),
                  cat: cat, 
                  totalPairs: widget.totalPairs,
                  index: idx,
                  onEnhanceChange: (val) => _onEnhanceChange(cat.name, val),
                  textShineController: _textShineController!,
                  isEnhanced: isEnhanced,
                  displayPct: displayPct,
                ),
                // Lucky Number Section with FADE Transition
                if (isEnhanced)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4), 
                    width: double.infinity,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchOutCurve: Curves.easeOut,
                      switchInCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) {
                         return Stack(
                           alignment: Alignment.topCenter,
                           children: [
                             ...previousChildren,
                             if (currentChild != null) currentChild,
                           ],
                         );
                      },
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: cat.suggestedNumber != null 
                      ? LuckyNumberCard(
                          key: ValueKey(cat.suggestedNumber!['number']),
                          phoneNumber: cat.suggestedNumber!['number'] ?? '---',
                          sum: int.tryParse(cat.suggestedNumber!['sum'].toString()) ?? 0,
                          isVip: cat.suggestedNumber!['is_vip'] == true,
                          keywords: List<String>.from(cat.suggestedNumber!['keywords'] ?? []),
                          themeColor: cat.color, 
                          buyButtonLabel: 'ซื้อเบอร์นี้',
                          onBuy: () {
                            showDialog(
                              context: context,
                              builder: (context) => ContactPurchaseModal(phoneNumber: cat.suggestedNumber!['number'] ?? ''),
                            );
                          },
                          onAnalyze: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NumberAnalysisPage(),
                                settings: RouteSettings(arguments: cat.suggestedNumber!['number']),
                              ),
                            );
                          }, 
                          onClose: () => _onEnhanceChange(cat.name, false),
                      )
                      : const LuckyNumberSkeleton(key: ValueKey('skeleton')),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),

        // Hint Text (Moved to bottom)
        _buildHintText(),

      ],
      ),
    );
  }

  Widget _buildHintText() {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('💡 แตะไอคอน ', style: GoogleFonts.kanit(fontSize: 10, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
            Container(
              width: 14, height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFDB931)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 3, offset: const Offset(0, 1))],
              ),
              child: const Icon(Icons.autorenew, size: 10, color: Colors.white),
            ),
            Text(' เพื่อเปลี่ยนเบอร์มงคล', style: GoogleFonts.kanit(fontSize: 10, color: const Color(0xFF64748B), fontStyle: FontStyle.italic)),
          ],
        ),
      );
  }

  Widget _buildLegendHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('หมวดหมู่', style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
          Expanded(flex: 2, child: Center(child: Text('%ดี', style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))))),
          Expanded(flex: 2, child: Center(child: Text('%ร้าย', style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))))),
          Expanded(
            flex: 2, 
            child: Align(
              alignment: Alignment.centerRight, 
              child: Text(
                'เสริมเบอร์', 
                style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                textAlign: TextAlign.right, 
              )
            )
          ),
        ],
      ),
    );
  }
  
  Widget _buildTotalScoreRow(List<CategoryData> chartData) {
     final score = widget.grandTotalScore;
     final isPositive = score >= 0;
     
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white, // Clean background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('คะแนนรวม', style: GoogleFonts.kanit(fontSize: 16, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
               Text(isPositive ? '😊' : '😭', style: const TextStyle(fontSize: 48)),
               const SizedBox(width: 16),
               Text(
                 '${isPositive ? '+' : ''}$score',
                 style: GoogleFonts.kanit(
                   fontSize: 56, 
                   fontWeight: FontWeight.w900, 
                   color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                   height: 1.0,
                 ),
               ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
               _buildPill('ดี +${widget.totalPositiveScore}', const Color(0xFFECFDF5), const Color(0xFF10B981)),
               const SizedBox(width: 12),
               _buildPill('ร้าย ${widget.totalNegativeScore}', const Color(0xFFFEF2F2), const Color(0xFFEF4444)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPill(String text, Color bg, Color fg) {
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
          child: Text(text, style: GoogleFonts.kanit(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
      );
  }
  

}

// --- PAINTER & MODEL ---

class CategoryData {
  final String name;
  final num good;
  final num bad;
  final Color color;
  final List<String> keywords;
  final Map<String, dynamic>? suggestedNumber;

  CategoryData({
    required this.name,
    required this.good,
    required this.bad,
    required this.color,
    required this.keywords,
    this.suggestedNumber,
  });
}

class NestedDonutPainter extends CustomPainter {
  final List<CategoryData> data;
  final int totalPairs;
  final Set<String> enhancedCategories;
  final double progress; // 0.0 to 1.0

  NestedDonutPainter({
    required this.data,
    required this.totalPairs,
    required this.enhancedCategories,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 32.0;

    // Draw Background Track
    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth/2, bgPaint);
    
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    CategoryData? getData(String name) {
      try { return data.firstWhere((d) => d.name == name); } catch (e) { return null; }
    }

    final quadrants = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'];

    // MODE 1: Standard
    if (enhancedCategories.isEmpty) {
       for (int i = 0; i < 4; i++) {
         final catName = quadrants[i];
         final catData = getData(catName);

         if (catData != null && catData.good > 0) {
            final startAngle = -math.pi / 2 + (i * math.pi / 2);
            double sweepAngle = math.pi / 2;
            
            // Animation Wipe Effect
            sweepAngle = sweepAngle * progress;

            _drawSegment(canvas, rect, startAngle, sweepAngle, catData.color, strokeWidth, center, radius, "25%");
         }
       }
       return;
    }

    // MODE 2: Dynamic
    double totalUnits = 6.0;
    double activeBaseCost = 1.5;
    
    int activeCount = 0;
    for (var name in quadrants) {
      final d = getData(name);
      if (d != null && d.good > 0) activeCount++;
    }
    
    double allocated = activeCount * activeBaseCost;
    double remaining = totalUnits - allocated;
    
    int enhancerCount = enhancedCategories.length;
    double bonusPerEnhancer = enhancerCount > 0 ? remaining / enhancerCount : 0.0;
    
    double currentStartAngle = -math.pi / 2;

    for (var name in quadrants) {
      final catData = getData(name);
      
      double weight = 0.0;
      if (catData != null && catData.good > 0) weight += activeBaseCost;
      if (enhancedCategories.contains(name)) weight += bonusPerEnhancer;

      if (weight > 0) {
        double sweepAngle = (weight / totalUnits) * (2 * math.pi);
        
        // Animation Wipe Effect
        double drawSweep = sweepAngle * progress; // Grow sweep
        
        Color color = catData?.color ?? Colors.grey;
        int pct = (weight / totalUnits * 100).round();
        
        _drawSegment(canvas, rect, currentStartAngle, drawSweep, color, strokeWidth, center, radius, "$pct%");
        
        // IMPORTANT: Increment by full sweepAngle (structure) or drawSweep? 
        // If increment by drawSweep, it creates "Fan Opening" effect (segments stick together).
        // If increment by full sweepAngle, segments appear in place and just grow.
        // "Fan Opening" (drawSweep) is cooler ("วิ่งปืดๆ").
        currentStartAngle += drawSweep;
      }
    }
  }

  void _drawSegment(Canvas canvas, Rect rect, double start, double sweep, Color categoryColor, double strokeWidth, Offset center, double radius, String label) {
       List<Color> gradientColors;
       if (categoryColor.value == 0xFF42A5F5) { // Blue
          gradientColors = [const Color(0xFF90CAF9), const Color(0xFF42A5F5)];
       } else if (categoryColor.value == 0xFFFFA726) { // Orange
          gradientColors = [const Color(0xFFFFCC80), const Color(0xFFFFA726)];
       } else if (categoryColor.value == 0xFFEC407A) { // Pink
          gradientColors = [const Color(0xFFF48FB1), const Color(0xFFEC407A)];
       } else if (categoryColor.value == 0xFF26A69A) { // Teal
          gradientColors = [const Color(0xFF80CBC4), const Color(0xFF26A69A)];
       } else {
          gradientColors = [categoryColor.withOpacity(0.7), categoryColor];
       }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..shader = LinearGradient(
             begin: Alignment.topLeft,
             end: Alignment.bottomRight,
             colors: gradientColors,
             tileMode: TileMode.mirror
        ).createShader(rect);

      canvas.drawArc(rect, start, sweep, false, paint);
      
      // Gap
      if (sweep > 0.1) {
         final gapPaint = Paint()
           ..color = Colors.white
           ..style = PaintingStyle.stroke
           ..strokeWidth = strokeWidth + 2
           ..strokeCap = StrokeCap.butt;
         const gapSize = 0.03;
         canvas.drawArc(rect, start + sweep - gapSize, gapSize, false, gapPaint);
      }
      
      // TEXT LABEL
       if (sweep < 0.1) return;
       // Only draw text if progress is near completion, otherwise it flies around weirdly
       if (sweep < 0.2) return; 

       final labelAngle = start + sweep / 2;
       final labelRadius = radius - strokeWidth / 2;
       final dx = center.dx + labelRadius * math.cos(labelAngle);
       final dy = center.dy + labelRadius * math.sin(labelAngle);
 
       final textSpan = TextSpan(
         text: label,
         style: GoogleFonts.kanit(
           color: Colors.white, 
           fontWeight: FontWeight.bold, 
           fontSize: 14,
           shadows: [const Shadow(blurRadius: 2, color: Colors.black26)],
         ),
       );
       final textPainter = TextPainter(
         text: textSpan,
         textDirection: TextDirection.ltr,
       );
       textPainter.layout();
       textPainter.paint(canvas, Offset(dx - textPainter.width / 2, dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(NestedDonutPainter oldDelegate) => true;
}

// --- LEGEND ROW WIDGET ---
class CategoryLegendRow extends StatelessWidget {
  final CategoryData cat;
  final int totalPairs;
  final int index;
  final Function(bool) onEnhanceChange;
  final AnimationController textShineController;
  final bool isEnhanced;
  final int displayPct; 

  const CategoryLegendRow({
    super.key,
    required this.cat,
    required this.totalPairs,
    required this.index,
    required this.onEnhanceChange,
    required this.textShineController,
    required this.isEnhanced,
    required this.displayPct,
  });

  @override
  Widget build(BuildContext context) {
    bool isActive = cat.good > 0 || isEnhanced; 
    bool hasBad = cat.bad > 0;
    bool showColor = isActive || hasBad; 
    int goodPct = displayPct;
    int badPct = totalPairs > 0 ? ((cat.bad / totalPairs) * 100).ceil() : 0;

    return Container(
      // Zebra striping: even rows get light background
      decoration: BoxDecoration(
        color: index % 2 == 0 ? const Color(0xFFF9FAFB) : Colors.white,
        // No borderRadius for sharp edges
      ),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: showColor ? cat.color : Colors.grey[300], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.name, 
                        style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: showColor ? const Color(0xFF1E293B) : Colors.grey[400]),
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  child: isActive 
                  ? Text('${goodPct > 0 ? goodPct : "-"}%', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: cat.color))
                  : Text('-', style: GoogleFonts.kanit(fontSize: 16, color: Colors.grey[300])),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  child: cat.bad > 0
                  ? Text('${badPct}%', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)))
                  : Text('-', style: GoogleFonts.kanit(fontSize: 16, color: Colors.grey[300])),
                ),
              ),
              Expanded(
                flex: 2,
                child: SizedBox(
                   height: 32,
                   child: Align(
                    alignment: Alignment.centerRight,
                    child: _EnhanceButton(
                      isActive: isActive,
                      isEnhanced: isEnhanced,
                      onChanged: onEnhanceChange,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (cat.keywords.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8), 
              child: Text(
                cat.keywords.join(', '),
                style: GoogleFonts.kanit(
                  fontSize: 13, 
                  color: hasBad ? const Color(0xFFEF4444) : (showColor ? Colors.grey[600]! : Colors.grey[400]!),
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Text(
                '-',
                style: GoogleFonts.kanit(
                  fontSize: 13, 
                  color: hasBad ? const Color(0xFFEF4444) : Colors.grey[400],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnhanceButton extends StatelessWidget {
  final bool isActive;
  final bool isEnhanced;
  final Function(bool) onChanged;

  const _EnhanceButton({
    required this.isActive, 
    required this.isEnhanced,
    required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onChanged(true); // Always trigger 'true' to cycle/refresh number
      },
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFDB931)], // Gold Gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: isEnhanced ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: const Icon(
          Icons.autorenew, 
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }
}
