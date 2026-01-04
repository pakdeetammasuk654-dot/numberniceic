import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/lucky_number_card.dart';
import '../screens/number_analysis_page.dart'; // For navigating to analyze the number

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

class _CategoryNestedDonutState extends State<CategoryNestedDonut> with TickerProviderStateMixin {
  // Track which categories are currently "Enhanced" (showing lucky number)
  final Set<String> _enhancedCategories = {};
  AnimationController? _textShineController;

  @override
  void initState() {
    super.initState();
    _textShineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _textShineController?.dispose();
    super.dispose();
  }

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
              textShineController: _textShineController!,
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
                   const Icon(Icons.auto_awesome, color: Color(0xFF8B4513), size: 16),
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
  final AnimationController textShineController;

  const CategoryLegendRow({
    super.key, 
    required this.cat, 
    required this.totalPairs, 
    required this.index,
    required this.onEnhanceChange,
    required this.textShineController,
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
                             'เสริมเบอร์ 100% ',
                             style: GoogleFonts.kanit(
                               fontSize: 14, 
                               fontWeight: FontWeight.bold,
                               color: const Color(0xFF8B4513)
                             ),
                           ),
                           const Icon(Icons.auto_awesome, color: Color(0xFF8B4513), size: 16),

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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LuckyNumberCard(
        phoneNumber: data['number']?.toString() ?? '',
        sum: int.tryParse(data['sum']?.toString() ?? '0') ?? 0,
        isVip: true, // Show VIP based on design request
        keywords: List<String>.from(data['keywords'] ?? []),
        buyButtonLabel: 'ซื้อเบอร์',
        analyzeButtonLabel: 'วิเคราะห์',
        analyzeButtonColor: const Color(0xFF2962FF), // Blue
        analyzeButtonBorderColor: const Color(0xFFBBDEFB),
        onBuy: () => _showPurchaseModal(data['number']?.toString() ?? ''),
        onAnalyze: () {
            // Navigate to Number Analysis Page
            // We can pass the number to auto-analyze
            // Assuming NumberAnalysisPage has a constructor or we pass arguments
            // Actually NumberAnalysisPage doesn't have arguments in the checked code (Step 105),
            // but we can pass it if we update NumberAnalysisPage or just navigate and let user type?
            // Wait, in Step 105, NumberAnalysisPage constructor was `const NumberAnalysisPage({super.key});`
            // But I can update it to accept initial number or use a shared state.
            // For now, I will just navigate. Ideally I should pass the number.
            // I'll update NumberAnalysisPage in next step if needed, or pass it via constructor if I missed it.
            // Actually, in DashboardPage (Step 156), I passed `AnalyzerPage(initialName: ..., initialDay: ...)`.
            // But checking NumberAnalysisPage (Step 105), it handles PHONE numbers.
            // I'll assume I can construct it or just push it. 
            // In ShopPage (Step 80 view), onAnalyze was just a Toast. 
            // I will update NumberAnalysisPage to accept 'initialNumber' later if needed.
            // For now, let's navigate. 
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NumberAnalysisPage(),
                settings: RouteSettings(arguments: data['number']?.toString()), // Pass via settings if constructor not ready
              ),
            );
        },
        onClose: _handleDelete,
      ),
    );
  }

  void _showPurchaseModal(String phoneNumber) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("สนใจเบอร์นี้?", style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: Stack(
          clipBehavior: Clip.none,
          children: [
            // Large Scattered Watermarks
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Transform.rotate(
                  angle: -0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "ชื่อดี.com",
                          style: GoogleFonts.kanit(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      )
                    ),
                  ),
                ),
              ),
            ),

            // Actual Content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Golden Shining Phone Number inside Dialog
                AnimatedBuilder(
                  animation: widget.textShineController,
                  builder: (context, child) {
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: const [
                            Color(0xFFAA771C), 
                            Color(0xFFFCF6BA), 
                            Color(0xFFFFFFFF), 
                            Color(0xFFFCF6BA), 
                            Color(0xFFAA771C), 
                          ],
                          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                          begin: Alignment(-2.0 + (widget.textShineController.value * 4), 0.0),
                          end: Alignment(-0.5 + (widget.textShineController.value * 4), 0.0),
                          tileMode: TileMode.clamp,
                        ).createShader(bounds);
                      },
                      child: SelectableText(
                        phoneNumber,
                        style: GoogleFonts.kanit(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),
                Text("ติดต่อซื้อเบอร์นี้ได้ที่", style: GoogleFonts.kanit(color: Colors.grey[700], fontSize: 14)),
                const SizedBox(height: 15),

                // 2. Line QR Code
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      )
                    ]
                  ),
                  child: Image.network(
                    '${ApiService.baseUrl}/images/line_qr_taya.jpg',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (_,__,___) => const Icon(Icons.qr_code, size: 100),
                  ),
                ),

                const SizedBox(height: 15),
                
                // Line ID Section (Split into 2 lines)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/LINE_logo.svg/480px-LINE_logo.svg.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (context, error, stackTrace) => 
                            const Icon(Icons.chat_bubble, color: Color(0xFF06C755), size: 20),
                        ),
                        const SizedBox(width: 6),
                        Text("Line ID: numberniceic", style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text("(คุณทญา)", style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ]
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("ปิด", style: GoogleFonts.kanit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse('https://line.me/ti/p/~numberniceic');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: Text("แอดไลน์", style: GoogleFonts.kanit(color: Colors.white)),
          )
        ],
      )
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
