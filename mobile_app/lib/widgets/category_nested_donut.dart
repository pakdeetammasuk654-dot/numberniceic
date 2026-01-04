import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class CategoryNestedDonut extends StatefulWidget {
  final Map<String, dynamic> categoryBreakdown;
  final int totalPairs;

  const CategoryNestedDonut({
    super.key,
    required this.categoryBreakdown,
    required this.totalPairs,
  });

  @override
  State<CategoryNestedDonut> createState() => _CategoryNestedDonutState();
}

class _CategoryNestedDonutState extends State<CategoryNestedDonut> {
  // Track which categories are currently "Enhanced" (showing lucky number)
  final Set<String> _enhancedCategories = {};

  void _onEnhanceChange(String category, bool isEnhanced) {
    setState(() {
      if (isEnhanced) {
        _enhancedCategories.add(category);
      } else {
        _enhancedCategories.remove(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryBreakdown.isEmpty) return const SizedBox.shrink();

    // Prepare chart data - Include ALL categories
    final List<CategoryData> chartData = [];
    final List<String> categories = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'];

    for (var cat in categories) {
      final data = widget.categoryBreakdown[cat] ?? {};
      chartData.add(CategoryData(
        name: cat,
        good: data['good'] ?? 0,
        bad: data['bad'] ?? 0,
        color: _getCategoryColor(cat),
        keywords: List<String>.from(data['keywords'] ?? []),
      ));
    }

    return Column(
      children: [
        // Chart Section
        SizedBox(
          height: 220,
          child: Center(
            child: CustomPaint(
              size: const Size(200, 200),
              painter: NestedDonutPainter(
                data: chartData,
                totalPairs: widget.totalPairs,
                enhancedCategories: _enhancedCategories,
              ),
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
            return CategoryLegendRow(
              key: ValueKey(cat.name),
              cat: cat, 
              totalPairs: widget.totalPairs,
              index: idx,
              onEnhanceChange: (isEnhanced) => _onEnhanceChange(cat.name, isEnhanced),
            );
          }).toList(),
        ),

        const Divider(height: 24),
        
        _buildTotalScoreRow(chartData),
        
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '💡 แตะไอคอน ',
                style: GoogleFonts.kanit(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFDB931)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.autorenew,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              Text(
                ' ซ้ำเพื่อเปลี่ยนเบอร์มงคล',
                style: GoogleFonts.kanit(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('หมวดหมู่', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
          Expanded(flex: 2, child: Center(child: Text('%ดี', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))))),
          Expanded(flex: 2, child: Center(child: Text('%ร้าย', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('เสริมเบอร์', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))))),
        ],
      ),
    );
  }
  
  Widget _buildTotalScoreRow(List<CategoryData> chartData) {
    // Web Match: Active Categories * 25
     int activeCategories = 0;
     for (var cat in chartData) {
       if (cat.good > 0) activeCategories++;
     }
     
     // Special Privilege: If ANY category is enhanced, Total Score jumps to 100%
     // Special Privilege: If ANY category is enhanced, Total Score jumps to 100%
     bool isEnhanced = _enhancedCategories.isNotEmpty;
     double finalScore = isEnhanced ? 100.0 : (activeCategories * 25).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Light blue-grey background
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('%รวม', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          
          // Score Value Display
          Container(
            padding: isEnhanced 
                ? const EdgeInsets.symmetric(horizontal: 20, vertical: 6) 
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: isEnhanced 
                ? BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFDB931)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))
                    ]
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                 if (!isEnhanced) Icon(Icons.emoji_events, color: finalScore >= 0 ? const Color(0xFFFFD700) : Colors.grey, size: 28),
                 if (!isEnhanced) const SizedBox(width: 8),
                 Text(
                   '${finalScore.round()}%',
                   style: GoogleFonts.kanit(
                     fontSize: 20,
                     fontWeight: FontWeight.w900,
                     color: isEnhanced ? const Color(0xFF8B4513) : (finalScore >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                   ),
                 ),
                 if (isEnhanced) ...[
                   const SizedBox(width: 4),
                   const Text('✨', style: TextStyle(fontSize: 16)),
                 ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    if (cat.contains('การงาน')) return const Color(0xFF90CAF9);
    if (cat.contains('สุขภาพ')) return const Color(0xFF80CBC4);
    if (cat.contains('การเงิน')) return const Color(0xFFFFCC80);
    if (cat.contains('ความรัก')) return const Color(0xFFF48FB1);
    return Colors.grey;
  }
}

class CategoryLegendRow extends StatefulWidget {
  final CategoryData cat;
  final int totalPairs;
  final int index;
  final Function(bool) onEnhanceChange;

  const CategoryLegendRow({
    super.key, 
    required this.cat, 
    required this.totalPairs, 
    required this.index,
    required this.onEnhanceChange,
  });

  @override
  State<CategoryLegendRow> createState() => _CategoryLegendRowState();
}

class _CategoryLegendRowState extends State<CategoryLegendRow> {
  bool _isExpanded = false;
  bool _isLoading = false;
  Map<String, dynamic>? _luckyData;
  int _currentIndex = 0;

  Future<void> _handleEnhance() async {
    setState(() {
      _isLoading = true;
    });

    // Determine next index
    int nextIndex = 0;
    if (_isExpanded && _luckyData != null) {
      // Already showing, increment to cycle
      nextIndex = _currentIndex + 1;
    } else {
      // First time, start at 0
      nextIndex = 0;
    }

    try {
      final data = await ApiService.getLuckyNumber(widget.cat.name, nextIndex);
      if (mounted) {
        final wasExpanded = _isExpanded;
        setState(() {
          _luckyData = data;
          _currentIndex = nextIndex;
          _isExpanded = true;
          _isLoading = false;
        });
        if (!wasExpanded) {
          widget.onEnhanceChange(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่พบเบอร์มงคลในหมวดหมู่ข้อมูลนี้')),
        );
      }
    }
  }

  void _handleDelete() {
    setState(() {
      _isExpanded = false;
      _luckyData = null;
      _currentIndex = 0;
    });
    widget.onEnhanceChange(false);
  }

  @override
  Widget build(BuildContext context) {
    // Always show row
    final cat = widget.cat;
    final totalPairs = widget.totalPairs;
    
    // Check if showing lucky
    final isShowingLucky = _isExpanded && _luckyData != null;

    // Force Table Row to match Chart Logic (25% Fixed)
    // If category has ANY good numbers -> Show 25% (Green)
    // If category has ANY bad numbers -> Show 25% (Red)
    // If Enhanced -> TREAT AS GOOD -> Show 100% (Green) to reflect "Perfect" status
    final percentGood = isShowingLucky ? 100 : (cat.good > 0 ? 25 : 0);
    final percentBad = cat.bad > 0 ? 25 : 0;

    return Container(
      color: widget.index % 2 != 0 ? const Color(0xFFF8F9FA) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              // Category Label (Flex 3)
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: cat.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: GoogleFonts.kanit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Good % (Flex 2)
              Expanded(
                flex: 2,
                child: Center(
                  child: cat.good > 0 
                      ? Text('$percentGood%', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32), fontSize: 16))
                      : Text('-', style: GoogleFonts.kanit(color: Colors.grey[400], fontSize: 16)),
                ),
              ),
              
              // Bad % (Flex 2)
              Expanded(
                flex: 2,
                child: Center(
                  child: cat.bad > 0 
                    ? Text('$percentBad%', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFFC62828), fontSize: 16))
                    : Text('-', style: GoogleFonts.kanit(color: Colors.grey[400], fontSize: 16)),
                ),
              ),
              
              // Action Icon (Flex 2)
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: _handleEnhance,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                       width: 36,
                       height: 36,
                       decoration: BoxDecoration(
                         gradient: const LinearGradient(
                           colors: [Color(0xFFFFD700), Color(0xFFFDB931)],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                         ),
                         shape: BoxShape.circle,
                         boxShadow: [
                           BoxShadow(
                             color: Colors.orange.withOpacity(0.3),
                             blurRadius: 4,
                             offset: const Offset(0, 2),
                           ),
                         ],
                       ),
                       child: _isLoading 
                         ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                         : const Icon(Icons.autorenew, size: 20, color: Colors.white), 
                     ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          // Content Area
          Column(
            children: [
                // 1. Keywords (Always show if present)
                if (cat.keywords.isNotEmpty)
                  Container(
                     width: double.infinity,
                     padding: const EdgeInsets.only(left: 24, bottom: 12),
                     child: Text(
                       cat.keywords.join(", "),
                       style: GoogleFonts.sarabun(fontSize: 14, color: Colors.grey[600]),
                       textAlign: TextAlign.left,
                     ),
                  ),

                // 2. Lucky Card OR Enhance Button
                if (isShowingLucky && _luckyData != null)
                  _buildLuckyCard(_luckyData!)
                else
                  // Enhance Button Tag (Yellow)
                  InkWell(
                     onTap: _handleEnhance,
                     borderRadius: BorderRadius.circular(24),
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                       decoration: BoxDecoration(
                         gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFDB931)]),
                         borderRadius: BorderRadius.circular(24),
                         boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.25), blurRadius: 6, offset:const Offset(0,3))],
                       ),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Icon(Icons.stars, color: Color(0xFF8B4513), size: 18),
                           const SizedBox(width: 8),
                           Text(
                             'เสริมเบอร์ 100% ✨',
                             style: GoogleFonts.kanit(
                               fontSize: 14, 
                               fontWeight: FontWeight.bold,
                               color: const Color(0xFF8B4513)
                             ),
                           )
                         ],
                       ),
                     ),
                   ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLuckyCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)), // Subtle gold border
        boxShadow: [
          BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Gold Gradient Phone Number with Shimmer Effect
          GoldShimmerText(
            text: data['number']?.toString() ?? '',
            fontSize: 34,
          ),
          
          if (data['sum'] != null && data['sum'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ผลรวม: ${data['sum']}',
              style: GoogleFonts.kanit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
          
          if (data['keywords'] != null && (data['keywords'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFFFF9E5), const Color(0xFFFEF3C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFD97706)], // Amber 700 to 600
                ).createShader(bounds),
                child: Text(
                  (data['keywords'] as List).join(' • '),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showPurchaseModal(data['number']?.toString() ?? ''),
                icon: const Icon(Icons.shopping_cart, size: 16),
                label: const Text('ซื้อเบอร์'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _handleDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[200]!.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: Colors.white,
                ),
                child: const Text('ลบ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPurchaseModal(String phoneNumber) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFF9FDF9)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  transform: Matrix4.rotationZ(-10 * 3.14159 / 180), // -10 deg
                  child: const Center(
                    child: Icon(Icons.shopping_cart_checkout, color: Color(0xFF2E7D32), size: 34),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  'สั่งซื้อเบอร์มงคล',
                  style: GoogleFonts.kanit(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1B5E20)),
                ),

                if (phoneNumber.isNotEmpty) ...[
                   const SizedBox(height: 16),
                   GoldShimmerText(text: phoneNumber, fontSize: 36),
                   const SizedBox(height: 8),
                ],

                const SizedBox(height: 12),
                
                // Description
                Text(
                  'ติดต่อสอบถามหรือสั่งซื้อกับคุณทญา\nทาง LINE ได้โดยตรงผ่าน QR Code นี้ครับ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[700], height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_in_talk, size: 20, color: Color(0xFF1B5E20)),
                      const SizedBox(width: 12),
                      SelectableText(
                        '093-654-4442',
                        style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20), letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // QR Code Image
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 10))],
                    border: Border.all(color: Colors.black.withOpacity(0.03)),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.network(
                        '${ApiService.baseUrl}/images/line_qr_taya.jpg',
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                           return Container(
                             width: 220, height: 220,
                             color: Colors.grey[100],
                             child: const Center(child: Text('ไม่สามารถโหลด QR Code ได้', textAlign: TextAlign.center)),
                           );
                        },
                      ),
                      // Line Icon Badge
                      Positioned(
                        bottom: -10,
                        right: -10,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF06C755),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: const Color(0xFF06C755).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: const Center(
                             child: Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                      shadowColor: const Color(0xFF1B5E20).withOpacity(0.4),
                    ),
                    child: Text('ตกลง', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ขอบคุณที่ไว้วางใจให้คุณทญาดูแลครับ',
                  style: GoogleFonts.kanit(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GoldShimmerText extends StatefulWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const GoldShimmerText({
    super.key, 
    required this.text, 
    this.fontSize = 24, 
    this.fontWeight = FontWeight.w900
  });

  @override
  State<GoldShimmerText> createState() => _GoldShimmerTextState();
}

class _GoldShimmerTextState extends State<GoldShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            // Shift the gradient across the text
            final shift = _controller.value * 2; // Move 2x width to ensure full cross
            return LinearGradient(
              colors: const [
                Color(0xFFBF953F), 
                Color(0xFFE6C86E), 
                Color(0xFFFFFAD3), // Highlight 
                Color(0xFFB38728), 
                Color(0xFFAA771C)
              ],
              stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
              begin: Alignment(-1.0 + shift, -0.5 + shift), 
              end: Alignment(1.0 + shift, 1.5 + shift),
              tileMode: TileMode.mirror, 
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: GoogleFonts.kanit(
              fontSize: widget.fontSize,
              fontWeight: widget.fontWeight,
              // Color doesn't matter much with srcIn/ShaderMask but keeping black ensures opacity
              color: Colors.black,
              height: 1.0,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.15), offset: const Offset(1, 2), blurRadius: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryData {
  final String name;
  final int good;
  final int bad;
  final Color color;
  final List<String> keywords;

  CategoryData({
    required this.name,
    required this.good,
    required this.bad,
    required this.color,
    required this.keywords,
  });
  
  int get total => good + bad;
}

class NestedDonutPainter extends CustomPainter {
  final List<CategoryData> data;
  final int totalPairs;
  final Set<String> enhancedCategories;

  NestedDonutPainter({
    required this.data, 
    required this.totalPairs,
    required this.enhancedCategories,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 35.0; // Thicker donut
    
    // Grey Background Ring
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    canvas.drawCircle(center, radius - strokeWidth/2, bgPaint);
    
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Helper: Find data by name
    CategoryData? getData(String name) {
      try {
        return data.firstWhere((d) => d.name == name);
      } catch (e) {
        return null;
      }
    }

    final quadrants = ['สุขภาพ', 'การงาน', 'การเงิน', 'ความรัก'];

    // MODE 1: Standard Fixed Quadrants (No Enhancements)
    if (enhancedCategories.isEmpty) {
       for (int i = 0; i < 4; i++) {
         final catName = quadrants[i];
         final catData = getData(catName);

         // Only draw active categories
         if (catData != null && catData.good > 0) {
            final startAngle = -math.pi / 2 + (i * math.pi / 2);
            final sweepAngle = math.pi / 2;
            
            _drawSegment(canvas, rect, startAngle, sweepAngle, catData.color, strokeWidth, center, radius, "25%");
         }
       }
       return;
    }

    // MODE 2: Dynamic Sizing (Enhancements Active)
    // Logic: Total Units = 6.0
    // Active Category Cost = 1.5
    // Remaining Units distributed among Enhancers
    
    double totalUnits = 6.0;
    double activeBaseCost = 1.5;
    
    // Calculate consumed by Actives
    int activeCount = 0;
    for (var name in quadrants) {
      final d = getData(name);
      if (d != null && d.good > 0) {
        activeCount++;
      }
    }
    
    double allocated = activeCount * activeBaseCost;
    double remaining = totalUnits - allocated;
    
    // Calculate Bonus for Enhancers
    int enhancerCount = enhancedCategories.length;
    double bonusPerEnhancer = enhancerCount > 0 ? remaining / enhancerCount : 0.0;
    
    double currentStartAngle = -math.pi / 2; // Start at 12 o'clock

    for (var name in quadrants) {
      final catData = getData(name);
      
      double weight = 0.0;
      
      // 1. Base Weight (if Active)
      if (catData != null && catData.good > 0) {
        weight += activeBaseCost;
      }
      
      // 2. Bonus Weight (if Enhanced)
      if (enhancedCategories.contains(name)) {
        weight += bonusPerEnhancer;
      }

      if (weight > 0) {
        // Calculate Sweep
        // fraction = weight / 6.0
        double sweepAngle = (weight / totalUnits) * (2 * math.pi);
        
        // Color: Use category color. If category data missing (shouldn't happen for defined quadrants but safe fallback), use grey
        Color color = catData?.color ?? Colors.grey;
        
        // Calculate Percentage
        int pct = (weight / totalUnits * 100).round();
        
        _drawSegment(canvas, rect, currentStartAngle, sweepAngle, color, strokeWidth, center, radius, "$pct%");
        
        currentStartAngle += sweepAngle;
      }
    }
  }

  void _drawSegment(Canvas canvas, Rect rect, double start, double sweep, Color color, double strokeWidth, Offset center, double radius, String label) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, start, sweep, false, paint);
      
      // Shield against tiny segments having overlapping text
      if (sweep < 0.1) return;

      // Label Position
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
  bool shouldRepaint(NestedDonutPainter oldDelegate) {
     return oldDelegate.data != data || 
            oldDelegate.enhancedCategories != enhancedCategories || 
            oldDelegate.totalPairs != totalPairs;
  }
}
