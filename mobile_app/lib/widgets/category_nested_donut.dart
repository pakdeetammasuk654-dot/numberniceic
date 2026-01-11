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
  final String? analyzedName;
  final Function(String phoneNumber)? onAddPhoneNumber; // Just for notification

  const CategoryNestedDonut({
    super.key,
    required this.categoryBreakdown,
    required this.totalPairs,
    required this.grandTotalScore,
    required this.totalPositiveScore,
    required this.totalNegativeScore,
    this.analyzedName,
    this.onAddPhoneNumber,
  });

  @override
  State<CategoryNestedDonut> createState() => _CategoryNestedDonutState();
}

class _CategoryNestedDonutState extends State<CategoryNestedDonut> with TickerProviderStateMixin {
  final Set<String> _enhancedCategories = {};
  final Map<String, Map<String, dynamic>?> _fetchedLuckyNumbers = {}; 
  final Map<String, int> _categoryIndices = {};
  
  // Store added phone numbers grouped by category
  final Map<String, List<Map<String, dynamic>>> _addedPhoneNumbersByCategory = {};
  
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
      duration: const Duration(milliseconds: 4500),
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
    if (!isEnhanced) {
      // Close action - not needed for bottom sheet approach
      return;
    }

    // Show bottom sheet with 3 lucky numbers
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LuckyNumbersBottomSheet(
        category: category,
        categoryColor: _getCategoryColor(category),
        analyzedName: widget.analyzedName,
        onAddPhoneNumber: (phoneNumber, sum, keywords) {
          _handleAddPhoneNumber(category, phoneNumber, sum, keywords);
        },
      ),
    );
  }

  // Handle adding phone number
  void _handleAddPhoneNumber(String category, String phoneNumber, int sum, List<String> keywords) {
    setState(() {
      // Initialize category list if not exists
      if (!_addedPhoneNumbersByCategory.containsKey(category)) {
        _addedPhoneNumbersByCategory[category] = [];
      }
      
      // Add/Replace phone number to category (Limit 1 per category)
      _addedPhoneNumbersByCategory[category] = [{
        'number': phoneNumber,
        'sum': sum,
        'keywords': keywords,
      }];
    });
    
    // Animate chart change
    _chartController.forward(from: 0.0);
    
    // Notify parent (just for SnackBar)
    if (widget.onAddPhoneNumber != null) {
      widget.onAddPhoneNumber!(phoneNumber);
    }
  }

  // Handle removing phone number
  void _handleRemovePhoneNumber(String category, int index) {
    setState(() {
      if (_addedPhoneNumbersByCategory.containsKey(category)) {
        _addedPhoneNumbersByCategory[category]!.removeAt(index);
        
        // Remove category key if list is empty
        if (_addedPhoneNumbersByCategory[category]!.isEmpty) {
          _addedPhoneNumbersByCategory.remove(category);
        }
        
        print('🔴 Removed phone number at index $index from category $category');
      }
    });

    // Animate chart change
    _chartController.forward(from: 0.0);
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
    
    // Combine manual enhanced categories and categories with added phone numbers
    final allEnhanced = Set<String>.from(_enhancedCategories)
      ..addAll(_addedPhoneNumbersByCategory.keys);
      
    bool isEnhancedAny = allEnhanced.isNotEmpty;
    double finalScoreTarget = isEnhancedAny ? 100.0 : (activeCategories * 25.0);
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
                        enhancedCategories: allEnhanced, // Use combined set
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
                                style: GoogleFonts.kanit(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)
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
            bool isEnhanced = allEnhanced.contains(cat.name);
            
            // Percentage Logic
            int displayPct = 0;
            int activeCount = 0;
            for (var c in chartData) { if (c.good > 0) activeCount++; }

            if (allEnhanced.isEmpty) {
               if (cat.good > 0) displayPct = 25;
            } else {
               double totalUnits = 6.0;
               double activeBaseCost = 1.5;
               double allocated = activeCount * activeBaseCost;
               double remaining = totalUnits - allocated;
               int enhancerCount = allEnhanced.length;
               double bonus = enhancerCount > 0 ? remaining / enhancerCount : 0.0;
               
               double weight = 0.0;
               if (cat.good > 0) weight += activeBaseCost;
               if (isEnhanced) weight += bonus;
               if (weight > 0) displayPct = (weight / totalUnits * 100).round();
            }

            return CategoryLegendRow(
              key: ValueKey(cat.name),
              cat: cat, 
              totalPairs: widget.totalPairs,
              index: idx,
              onEnhanceChange: (val) => _onEnhanceChange(cat.name, val),
              textShineController: _textShineController!,
              isEnhanced: isEnhanced,
              displayPct: displayPct,
              addedPhoneNumbers: _addedPhoneNumbersByCategory[cat.name],
              onRemovePhoneNumber: _handleRemovePhoneNumber,
            );
          }).toList(),
        ),



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
                'เติมกราฟ', 
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
  final List<Map<String, dynamic>>? addedPhoneNumbers;
  final Function(String category, int index)? onRemovePhoneNumber; // NEW

  const CategoryLegendRow({
    super.key,
    required this.cat,
    required this.totalPairs,
    required this.index,
    required this.onEnhanceChange,
    required this.textShineController,
    required this.isEnhanced,
    required this.displayPct,
    this.addedPhoneNumbers,
    this.onRemovePhoneNumber, // NEW
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
                  ? Text('${badPct}%', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: const Color(0xFF64748B)))
                  : Text('-', style: GoogleFonts.kanit(fontSize: 16, color: Colors.grey[300])),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _EnhanceButton(
                    isActive: isActive,
                    isEnhanced: isEnhanced,
                    onChanged: onEnhanceChange,
                    categoryColor: cat.color,
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
                  color: hasBad ? const Color(0xFF64748B) : (showColor ? Colors.grey[600]! : Colors.grey[400]!),
                  fontWeight: hasBad ? FontWeight.bold : FontWeight.normal,
                  fontStyle: hasBad ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ] else if (addedPhoneNumbers == null || addedPhoneNumbers!.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Text(
                '-',
                style: GoogleFonts.kanit(
                  fontSize: 13, 
                  color: hasBad ? const Color(0xFF64748B) : Colors.grey[400],
                  fontWeight: hasBad ? FontWeight.bold : FontWeight.normal,
                  fontStyle: hasBad ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
          
          // Added Phone Numbers
          if (addedPhoneNumbers != null && addedPhoneNumbers!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...addedPhoneNumbers!.asMap().entries.map((entry) {
              final phoneIndex = entry.key;
              final phoneData = entry.value;
              final phoneNumber = phoneData['number'] as String;
              final sum = phoneData['sum'] as int;
              final keywords = phoneData['keywords'] as List<String>;
              
              return TweenAnimationBuilder<double>(
                key: ValueKey(phoneNumber),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutQuart,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 20, right: 8, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.08), // Using category color (lighter)
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cat.color.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: cat.color.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Keywords
                      if (keywords.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            keywords.join(', '),
                            style: GoogleFonts.sarabun(
                              fontSize: 16,
                              color: const Color(0xFF334155), // Slicker Dark Blue-Grey
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      // Phone number and sum
                      // Phone number and sum
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedBuilder(
                              animation: textShineController,
                              builder: (context, child) {
                                return ShaderMask(
                                  blendMode: BlendMode.srcIn,
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: const [
                                        Color(0xFF8E6E12), // Dark Gold
                                        Color(0xFFF1C40F), // Gold
                                        Color(0xFFFFFAD8), // Light Gold
                                        Color(0xFFF1C40F), // Gold
                                        Color(0xFF8E6E12), // Dark Gold
                                      ],
                                      stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                                      begin: Alignment(-2.5 + (textShineController.value * 5), 0.0),
                                      end: Alignment(-1.0 + (textShineController.value * 5), 0.0),
                                      tileMode: TileMode.clamp,
                                    ).createShader(bounds);
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        phoneNumber,
                                        style: GoogleFonts.kanit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white, // Color is overridden by ShaderMask
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '($sum)',
                                        style: GoogleFonts.kanit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // Remove button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                if (onRemovePhoneNumber != null) {
                                  onRemovePhoneNumber!(cat.name, phoneIndex);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Icon(Icons.close, size: 18, color: cat.color.withOpacity(0.7)),
                              ),
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}

class _EnhanceButton extends StatefulWidget {
  final bool isActive;
  final bool isEnhanced;
  final Function(bool) onChanged;
  final Color categoryColor;

  const _EnhanceButton({
    required this.isActive, 
    required this.isEnhanced,
    required this.onChanged,
    required this.categoryColor,
  });

  @override
  State<_EnhanceButton> createState() => _EnhanceButtonState();
}

class _EnhanceButtonState extends State<_EnhanceButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Create lighter and darker versions of the category color for gradient
    final HSLColor hslColor = HSLColor.fromColor(widget.categoryColor);
    final Color lightColor = hslColor.withLightness((hslColor.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    final Color darkColor = hslColor.withLightness((hslColor.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final Color borderColor = hslColor.withLightness((hslColor.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        widget.onChanged(true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [lightColor, widget.categoryColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: _isPressed 
            ? [
                BoxShadow(color: widget.categoryColor.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 0))
              ]
            : [
                BoxShadow(color: darkColor, blurRadius: 0, offset: const Offset(0, 3)), // 3D Depth
                BoxShadow(color: widget.categoryColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 4)), // Soft Shadow
              ]
        ),
        transform: Matrix4.identity()..translate(0.0, _isPressed ? 3.0 : 0.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              'เสริม',
              style: GoogleFonts.kanit(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                height: 1.2
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom Sheet Widget for displaying 3 lucky numbers
class _LuckyNumbersBottomSheet extends StatefulWidget {
  final String category;
  final Color categoryColor;
  final String? analyzedName;
  final Function(String phoneNumber, int sum, List<String> keywords)? onAddPhoneNumber;
  final Function(String phoneNumber)? onNotifyParent;

  const _LuckyNumbersBottomSheet({
    required this.category,
    required this.categoryColor,
    this.analyzedName,
    this.onAddPhoneNumber,
    this.onNotifyParent,
  });

  @override
  State<_LuckyNumbersBottomSheet> createState() => _LuckyNumbersBottomSheetState();
}

class _LuckyNumbersBottomSheetState extends State<_LuckyNumbersBottomSheet> {
  List<Map<String, dynamic>>? _luckyNumbers;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLuckyNumbers();
  }

  Future<void> _fetchLuckyNumbers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch 3 numbers (index 0, 1, 2)
      final List<Map<String, dynamic>> numbers = [];
      for (int i = 0; i < 3; i++) {
        final result = await ApiService.getLuckyNumber(widget.category, index: i);
        if (result != null) {
          numbers.add(result);
        }
      }

      if (mounted) {
        setState(() {
          _luckyNumbers = numbers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'เกิดข้อผิดพลาดในการโหลดข้อมูล';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.categoryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.kanit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                    children: [
                      const TextSpan(text: 'หมายเลขไร้ที่ติ '),
                      TextSpan(
                        text: '"${widget.category}"',
                        style: TextStyle(color: widget.categoryColor),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(60),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                _error!,
                style: GoogleFonts.kanit(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            )
          else if (_luckyNumbers == null || _luckyNumbers!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'ไม่พบข้อมูลเบอร์มงคล',
                style: GoogleFonts.kanit(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Keywords Header (shown once)
                  if (_luckyNumbers!.isNotEmpty && _luckyNumbers![0]['keywords'] != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.categoryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.sarabun(
                            fontSize: 20,
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w900,
                            height: 1.3,
                          ),
                          children: [
                            if (widget.analyzedName != null && widget.analyzedName!.isNotEmpty) ...[
                              TextSpan(
                                text: '${widget.analyzedName}" ',
                                style: GoogleFonts.sarabun(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: widget.categoryColor,
                                ),
                              ),
                            ],
                            const TextSpan(text: 'เบอร์ส่งเสริม:\n'),
                            TextSpan(
                              text: (List<String>.from(_luckyNumbers![0]['keywords'] ?? [])).join(', '),
                              style: TextStyle(
                                color: widget.categoryColor,
                                decoration: TextDecoration.underline,
                                decorationColor: widget.categoryColor.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Phone Numbers List
                  ..._luckyNumbers!.asMap().entries.map((entry) {
                    final number = entry.value;
                    final phoneNumber = number['number'] ?? '---';
                    final sum = int.tryParse(number['sum'].toString()) ?? 0;
                    final keywords = List<String>.from(number['keywords'] ?? []);
                    
                    return _CompactPhoneRow(
                      phoneNumber: phoneNumber,
                      sum: sum,
                      categoryColor: widget.categoryColor,
                      onAdd: () {
                        // Close bottom sheet
                        Navigator.pop(context);
                        
                        // Add phone number to CategoryNestedDonut state
                        if (widget.onAddPhoneNumber != null) {
                          widget.onAddPhoneNumber!(phoneNumber, sum, keywords);
                        }
                        
                        // Notify parent for SnackBar
                        if (widget.onNotifyParent != null) {
                          widget.onNotifyParent!(phoneNumber);
                        }
                      },
                      onBuy: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => ContactPurchaseModal(
                            phoneNumber: phoneNumber,
                          ),
                        );
                      },
                      onAnalyze: () {
                        // Close the lucky numbers bottom sheet first
                        Navigator.pop(context);
                        // Show the analysis as a new bottom sheet
                        NumberAnalysisPage.show(context, phoneNumber: phoneNumber);
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Compact Phone Row for Bottom Sheet
class _CompactPhoneRow extends StatefulWidget {
  final String phoneNumber;
  final int sum;
  final Color categoryColor;
  final VoidCallback onAdd;
  final VoidCallback onBuy; // Keep parameter but maybe ignored in build if UI removed
  final VoidCallback onAnalyze;

  const _CompactPhoneRow({
    required this.phoneNumber,
    required this.sum,
    required this.categoryColor,
    required this.onAdd,
    required this.onBuy,
    required this.onAnalyze,
  });

  @override
  State<_CompactPhoneRow> createState() => _CompactPhoneRowState();
}

class _CompactPhoneRowState extends State<_CompactPhoneRow> with SingleTickerProviderStateMixin {
  late AnimationController _shineController;
  
  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 4500),
    )..repeat();
  }
  
  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Phone Number and Sum
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedBuilder(
                      animation: _shineController,
                      builder: (context, child) {
                        return ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: const [
                                Color(0xFF8E6E12), // Dark Gold
                                Color(0xFFF1C40F), // Gold
                                Color(0xFFFFFAD8), // Light Gold
                                Color(0xFFF1C40F), // Gold
                                Color(0xFF8E6E12), // Dark Gold
                              ],
                              stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                              begin: Alignment(-2.5 + (_shineController.value * 5), 0.0),
                              end: Alignment(-1.0 + (_shineController.value * 5), 0.0),
                              tileMode: TileMode.clamp,
                            ).createShader(bounds);
                          },
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: widget.phoneNumber,
                                  style: GoogleFonts.kanit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white, // Overridden by ShaderMask
                                    letterSpacing: 1.2,
                                    height: 1.0,
                                  ),
                                ),
                                TextSpan(
                                  text: ' (${widget.sum})',
                                  style: GoogleFonts.kanit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white, // Overridden by ShaderMask
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Add Button (3D Green)
                _build3DButton(
                  icon: Icons.add_circle,
                  color: const Color(0xFF10B981),
                  onTap: widget.onAdd,
                ),
                
                const SizedBox(width: 10),
                
                // Analyze Button (3D Blue)
                _build3DButton(
                  icon: Icons.query_stats,
                  color: const Color(0xFF3B82F6),
                  onTap: widget.onAnalyze,
                ),
              ],
            ),
          ),
        ),
        // Thin divider
        Container(
          height: 1,
          color: Colors.grey[200],
        ),
      ],
    );
  }

  Widget _build3DButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final HSLColor hsl = HSLColor.fromColor(color);
    final Color lightColor = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    final Color darkColor = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
    final Color shadowColor = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lightColor,
            color,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 3), // 3D Depth
            blurRadius: 0,
          ),
          BoxShadow(
            color: color.withOpacity(0.3),
            offset: const Offset(0, 5), // Soft drop shadow
            blurRadius: 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
