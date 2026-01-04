import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sample_name.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/shared_footer.dart';
import '../widgets/upgrade_dialog.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'main_tab_page.dart';
import '../widgets/premium_donut_chart.dart';
import '../widgets/category_nested_donut.dart';
import 'numerology_detail_page.dart';
import 'linguistic_detail_page.dart';
import 'shop_page.dart';
import 'login_page.dart';


class AnalyzerPage extends StatefulWidget {
  final String? initialName;
  final String? initialDay;

  const AnalyzerPage({super.key, this.initialName, this.initialDay});

  @override
  State<AnalyzerPage> createState() => _AnalyzerPageState();
}

class _AnalyzerPageState extends State<AnalyzerPage> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedDay = 'sunday';
  bool _isAuspicious = false;
  bool _showKlakini = true;
  bool _isLoading = false;
  bool _isSolarLoading = false;
  bool _isNamesLoading = false;
  Map<String, dynamic>? _analysisResult;
  late AnimationController _rotationController;
  late AnimationController _rotationControllerOuter;
  late Future<bool> _isBuddhistDayFuture;
  late Future<Map<String, dynamic>> _userInfoFuture;
  bool _isLoggedIn = false;
  late Future<List<SampleName>> _sampleNamesFuture;
  Timer? _debounce;
  bool _showTop4 = false;
  bool _showKlakiniTop4 = true;
  bool _showScrollToTop = false;
  bool _isTop4Switching = false;

  final List<Map<String, dynamic>> _days = [
    {'value': 'sunday', 'label': 'วันอาทิตย์', 'icon': Icons.wb_sunny, 'color': Colors.red},
    {'value': 'monday', 'label': 'วันจันทร์', 'icon': Icons.brightness_2, 'color': Color(0xFFFFD600)},
    {'value': 'tuesday', 'label': 'วันอังคาร', 'icon': Icons.bolt, 'color': Colors.pink},
    {'value': 'wednesday1', 'label': 'วันพุธ (กลางวัน)', 'icon': Icons.wb_cloudy, 'color': Colors.green},
    {'value': 'wednesday2', 'label': 'วันพุธ (กลางคืน)', 'icon': Icons.nightlight_round, 'color': Color(0xFF1B5E20)},
    {'value': 'thursday', 'label': 'วันพฤหัสบดี', 'icon': Icons.auto_stories, 'color': Colors.orange},
    {'value': 'friday', 'label': 'วันศุกร์', 'icon': Icons.favorite, 'color': Colors.blue},
    {'value': 'saturday', 'label': 'วันเสาร์', 'icon': Icons.filter_vintage, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = (widget.initialName != null && widget.initialName!.isNotEmpty) 
        ? widget.initialName! 
        : 'ณเดชน์';
    
    // Normalize Day (Handle Thai names if passed)
    String rawDay = widget.initialDay ?? 'thursday';
    final dayMap = {
      'วันอาทิตย์': 'sunday',
      'วันจันทร์': 'monday',
      'วันอังคาร': 'tuesday',
      'วันพุธ': 'wednesday1',
      'วันพุธกลางวัน': 'wednesday1',
      'วันพุธ (กลางวัน)': 'wednesday1',
      'วันพุธกลางคืน': 'wednesday2',
      'วันพุธ (กลางคืน)': 'wednesday2',
      'วันพฤหัสบดี': 'thursday',
      'วันศุกร์': 'friday',
      'วันเสาร์': 'saturday',
    };
    
    _selectedDay = dayMap[rawDay] ?? rawDay.toLowerCase();
    
    // Safety check: ensure _selectedDay exists in _days list
    bool exists = _days.any((d) => d['value'] == _selectedDay);
    if (!exists) {
      _selectedDay = 'sunday';
    }

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Outer orbit radius is 140, Inner is 90.
    // To have same linear velocity, period T must be proportional to R.
    // T_outer = T_inner * (140 / 90) = 20 * 1.555... = ~31.11 seconds
    _rotationControllerOuter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 31111), 
    )..repeat();
    
    _isBuddhistDayFuture = ApiService.isBuddhistDayToday();
    _userInfoFuture = AuthService.getUserInfo();
    _sampleNamesFuture = ApiService.getSampleNames();

    // Always trigger analysis on start to show the Solar System initially
    _checkLoginStatus();
    _analyze();

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        bool show = _scrollController.offset > 150;
        if (show != _showScrollToTop) {
          setState(() {
            _showScrollToTop = show;
          });
        }
      }
    });
  }

  void _onInputChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _analyze();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rotationController.dispose();
    _rotationControllerOuter.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildPremiumStar(double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Subtle Glow
        Icon(Icons.star, color: const Color(0xFFFFD700).withOpacity(0.4), size: size + 4),
        // Darker Border
        Icon(Icons.star, color: const Color(0xFFB8860B), size: size + 1.5),
        // Main Gold Fill
        Icon(Icons.star, color: const Color(0xFFFFD700), size: size),
      ],
    );
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      String hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF' + hex;
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
  Future<void> _analyze() async {
    if (_nameController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSolarLoading = true;
      _isNamesLoading = true;
    });

    try {
      // Step 1: Fetch Solar System (FAST)
      final solarResult = await ApiService.analyzeName(
        _nameController.text,
        _selectedDay,
        auspicious: _isAuspicious,
        disableKlakini: !_showKlakini,
        disableKlakiniTop4: !_showKlakiniTop4,
        section: 'solar',
      );

      if (mounted) {
        setState(() {
          if (_analysisResult != null) {
            // Merge solar data without losing best_names/similar_names
            _analysisResult!.addAll(solarResult);
          } else {
            _analysisResult = Map<String, dynamic>.from(solarResult);
          }
          _isSolarLoading = false;
        });
      }

      // Step 2: Fetch Names (SLOWER)
      final namesResult = await ApiService.analyzeName(
        _nameController.text,
        _selectedDay,
        auspicious: _isAuspicious,
        disableKlakini: !_showKlakini,
        disableKlakiniTop4: !_showKlakiniTop4,
        section: 'names',
      );

      if (mounted) {
        setState(() {
          if (_analysisResult != null) {
            _analysisResult!.addAll(namesResult);
          } else {
            _analysisResult = Map<String, dynamic>.from(namesResult);
          }
          _isNamesLoading = false;
          _isLoading = false;
        });
        
        // Delay hiding skeleton to ensure it's visible (minimum 300ms)
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _isTop4Switching = false);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSolarLoading = false;
          _isNamesLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Widget _buildTop4Section() {
    // Show full skeleton if switching (even if _analysisResult is null)
    if (_isTop4Switching && _analysisResult == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Skeleton
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Toggles Skeleton
            Row(
              children: [
                Container(
                  width: 120,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  width: 150,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Grid Skeleton
            _buildTop4SkeletonGrid(),
          ],
        ),
      );
    }
    
    if (_analysisResult == null) return const SizedBox.shrink();
    
    final dynamic bestNamesObj = _analysisResult!['best_names'];
    if (bestNamesObj == null || bestNamesObj is! Map) return const SizedBox.shrink();

    final Map<String, dynamic> bestNames = Map<String, dynamic>.from(bestNamesObj);
    final List top4 = (bestNames['top_4'] as List? ?? []);
    final List recommended = (bestNames['recommended'] as List? ?? []);
    final List targetNameHtml = (bestNames['target_name_html'] as List? ?? []);

    final List names;
    final String titlePrefix;
    final bool isActuallyShowingTop4;

    if (_showTop4) {
      names = top4;
      titlePrefix = 'ตั้งชื่อดีให้ ';
      isActuallyShowingTop4 = true;
    } else {
      if (recommended.isNotEmpty) {
        names = recommended;
        // Override for custom format logic if needed, but backend sends prefix.
        // User requested: 'ชื่อดี "ณเดชน์" #97 - #100'
        // So we override the prefix here locally.
        titlePrefix = 'ตั้งชื่อดีให้ '; 
        isActuallyShowingTop4 = false;
      } else {
        names = top4;
        titlePrefix = 'ตั้งชื่อดีให้ ';
        isActuallyShowingTop4 = true;
      }
    }

    if (names.isEmpty) return const SizedBox.shrink();

    // Theme Logic
    final bool isGold = isActuallyShowingTop4;
    final Color themeColor = isGold ? const Color(0xFFFFD700) : const Color(0xFFC5E1A5);
    final List<Color> gradientColors = isGold 
        ? [Colors.white, const Color(0xFFFFFDE7)]
        : [Colors.white, const Color(0xFFF1F8E9)];

    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        margin: const EdgeInsets.only(bottom: 44, left: 16, right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Trophy (Premium Style)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF388E3C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            titlePrefix,
                            style: GoogleFonts.kanit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                          Text(' "', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2D3748))),
                          ...targetNameHtml.map((dc) => Text(
                            dc['char'] ?? '',
                            style: GoogleFonts.kanit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: dc['is_bad'] == true ? const Color(0xFFFF4757) : const Color(0xFFC59D00),
                            ),
                          )),
                          Text('"', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF2D3748))),
                        ],
                      ),
                      if (!isActuallyShowingTop4) 
                         Builder(builder: (context) {
                            final total = (bestNames['total_best'] as int? ?? 100);
                            final count = names.length;
                            final start = total - count + 1;
                            return Text(
                              'ลำดับที่ #$start - #$total',
                               style: GoogleFonts.kanit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.grey[600],
                                ),
                            );
                         }),
                    ],
                  ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Premium Toggles Container
          Row(
            children: [
              // Styled VIP Toggle Pill
              Container(
                padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
                decoration: BoxDecoration(
                  color: _showTop4 ? const Color(0xFFFFF1C1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _showTop4 ? const Color(0xFFFFD54F) : Colors.grey[300]!, width: 1.5),
                  boxShadow: [
                    if (_showTop4)
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: _showTop4 ? Colors.orange : Colors.grey[400], size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'VIP',
                      style: GoogleFonts.kanit(
                        fontSize: 16, 
                        fontWeight: FontWeight.w900, 
                        color: _showTop4 ? Colors.orange[800] : Colors.grey[500]
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 28,
                      width: 44,
                      child: Transform.scale(
                        scale: 0.9,
                        child: Switch(
                          value: _showTop4,
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF388E3C),
                          onChanged: (val) {
                            setState(() {
                              _isTop4Switching = true;
                              _showTop4 = val;
                            });
                            // Hide skeleton after brief delay
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted) {
                                setState(() => _isTop4Switching = false);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Styled Klakini Toggle
               Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   RichText(
                    text: TextSpan(
                      style: GoogleFonts.kanit(color: const Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.normal),
                      children: [
                        const TextSpan(text: 'แสดง'),
                        TextSpan(text: 'กาลกิณี', style: TextStyle(color: Colors.red[700])),
                      ]
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 28,
                    width: 44,
                    child: Transform.scale(
                      scale: 1.0,
                      child: Switch(
                      value: _showKlakiniTop4,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF388E3C),
                      onChanged: (val) {
                        setState(() {
                          _showKlakiniTop4 = val;
                          _isTop4Switching = true;
                        });
                        _analyze();
                      },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Best Names Grid (Premium Cards) - Single Container
          _isTop4Switching
              ? _buildTop4SkeletonGrid()
              : ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 310,
                  ),
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: themeColor, width: 2.5),
                      boxShadow: [], // Removed inner shadow
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Row
                        SizedBox(
                          height: 150,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _buildBestNameCardContent(names[0], isActuallyShowingTop4 ? 1 : (bestNames['total_best'] as int? ?? 100) - 3, isGold: isGold)),
                              Container(width: 2, color: themeColor),
                              Expanded(child: _buildBestNameCardContent(names[1], isActuallyShowingTop4 ? 2 : (bestNames['total_best'] as int? ?? 100) - 2, isGold: isGold)),
                            ],
                          ),
                        ),
                        Container(height: 2, color: themeColor),
                        // Bottom Row
                        SizedBox(
                          height: 150,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _buildBestNameCardContent(names[2], isActuallyShowingTop4 ? 3 : (bestNames['total_best'] as int? ?? 100) - 1, isGold: isGold)),
                              Container(width: 2, color: themeColor),
                              Expanded(child: _buildBestNameCardContent(names[3], isActuallyShowingTop4 ? 4 : (bestNames['total_best'] as int? ?? 100), isGold: isGold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    ));
  }

  Widget _buildBestNameCard(Map n, int rank) {
    final displayName = n['display_name_html'] as List? ?? [];
    final similarity = (n['similarity'] as num? ?? 0) * 100;
    final totalScore = n['total_score'] ?? 0;
    final meaning = n['meaning'] ?? 'สุขภาพแข็งแรง, ปลอดภัย, มั่นคง'; // Default or from API if available

    return InkWell(
      onTap: () {
        _nameController.text = n['th_name'] ?? '';
        _analyze();
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEF), // Light yellow background (Cream)
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFC107), // Gold border
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top-Right Badge "Top X"
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(22),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium, color: Color(0xFF4A3B00), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Top $rank',
                      style: GoogleFonts.kanit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A3B00),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Meaning / Keywords
                  Text(
                    'สุขภาพแข็งแรง, ปลอดภัย, มั่นคง', // Placeholder or use 'meaning' var if available
                    textAlign: TextAlign.center,
                    style: GoogleFonts.kanit(
                      fontSize: 16,
                      color: const Color(0xFF5D5D5D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Name (Gradient Text)
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFD4AF37), // Metallic Gold
                        Color(0xFFFFD700), // Yellow Gold
                        Color(0xFFB8860B), // Dark Goldenrod
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: displayName.map((dc) {
                        return Text(
                          dc['char'] ?? '',
                          style: GoogleFonts.kanit(
                            fontSize: 42, // Large Size matching the phone number in image
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Required for ShaderMask
                            height: 1.0,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Badges Row (Score + VIP)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Score Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE0B2), // Light Orange/Cream
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ผลรวม $totalScore',
                          style: GoogleFonts.kanit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8D6E63), // Brownish
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // VIP Badge
                      Row(
                        children: [
                          Text(
                            'ชื่อ VIP',
                            style: GoogleFonts.kanit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF795548), // Brown
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('✨', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Dashed Line (Reuse painter or create inline)
                  CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DashedLinePainter(),
                  ),
                  const SizedBox(height: 20),

                  // Buttons Row
                  Row(
                    children: [
                      // Buy Button -> "Use Name" or "Save"
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: () {
                             // Action to save name or select it
                             _nameController.text = n['th_name'] ?? '';
                             _analyze(); // Re-analyze/Select
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เลือกชื่อนี้เรียบร้อยแล้ว')));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981), // Vivid Green
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'เลือกใช้',
                                style: GoogleFonts.kanit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Analyze Button
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () {
                             // Scroll to top to see details
                             _nameController.text = n['th_name'] ?? '';
                             _analyze();
                             _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2962FF), // Bright Blue
                            side: const BorderSide(color: Color(0xFFBBDEFB), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                'วิเคราะห์',
                                style: GoogleFonts.kanit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestNameCardContent(Map n, int rank, {bool isGold = true}) {
    final displayName = n['display_name_html'] as List? ?? [];
    final similarity = (n['similarity'] as num? ?? 0) * 100;
    final totalScore = n['total_score'] ?? 0;
    
    // Calculate Sat and Sha sums from lists of strings
    final satNums = n['sat_num'] as List? ?? [];
    final shaNums = n['sha_num'] as List? ?? [];
    
    int sumSat = 0;
    for(var s in satNums) {
       sumSat += (int.tryParse(s.toString()) ?? 0);
    }
    int sumSha = 0;
    for(var s in shaNums) {
       sumSha += (int.tryParse(s.toString()) ?? 0);
    }
    
    // Theme Colors
    final Color badgeBg = isGold ? const Color(0xFFFFD700) : const Color(0xFF66BB6A);
    final Color badgeText = isGold ? const Color(0xFF4A3B00) : Colors.white;
    final String badgeLabel = isGold ? 'Top $rank' : '#$rank';
    final Color starColor = const Color(0xFFFFD700);
    final Color themeBorder = isGold ? const Color(0xFFFFD700) : const Color(0xFFC5E1A5);

    final List<Color> gradientColors = isGold 
        ? [Colors.white, const Color(0xFFFFFDE7)]
        : [Colors.white, const Color(0xFFF1F8E9)];

    return InkWell(
      onTap: () {
        _nameController.text = n['th_name'] ?? '';
        _analyze();
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      },
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 160,
          maxHeight: 180,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top-Right Badge "Top X" with Crown
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.zero,
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if(isGold) ...[
                      Icon(Icons.workspace_premium, color: badgeText, size: 10),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      badgeLabel,
                      style: GoogleFonts.kanit(
                        fontSize: 11,
                        fontWeight: isGold ? FontWeight.w900 : FontWeight.w400,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Card Content
            Padding(
             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
             child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Star + Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (n['is_top_tier'] == true) _buildPremiumStar(18),
                    if (n['is_top_tier'] == true) const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          maxLines: 1,
                          text: TextSpan(
                            children: displayName.map((dc) {
                              return TextSpan(
                                text: dc['char'] ?? '',
                                style: GoogleFonts.kanit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: dc['is_bad'] == true ? const Color(0xFFFF4757) : const Color(0xFFC59D00),
                                  shadows: n['is_top_tier'] == true ? [
                                    Shadow(
                                      color: const Color(0xFFC59D00).withOpacity(0.2),
                                      offset: const Offset(0, 1),
                                      blurRadius: 1,
                                    )
                                  ] : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                
                // Similarity & Score
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.kanit(fontSize: 11, color: const Color(0xFF2E7D32), fontWeight: FontWeight.w500),
                    children: [
                      const TextSpan(text: 'คล้าย '),
                      TextSpan(text: '${similarity.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const TextSpan(text: ' • ', style: TextStyle(color: Color(0xFFCBD5E0))),
                      const TextSpan(text: 'คะแนน '),
                      TextSpan(text: '$totalScore', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                
                // Score Circles
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                     ...n['t_sat']?.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final color = _parseColor(entry.value['color']);
                        final numStr = (n['sat_num'] as List?)?[idx]?.toString() ?? '';
                        return _buildScoreCircle(numStr, color);
                     }).toList() ?? [],
                     if ((n['t_sat'] as List?)?.isNotEmpty == true && (n['t_sha'] as List?)?.isNotEmpty == true)
                        const SizedBox(width: 2),
                     ...n['t_sha']?.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final color = _parseColor(entry.value['color']);
                        final numStr = (n['sha_num'] as List?)?[idx]?.toString() ?? '';
                        return _buildScoreCircle(numStr, color, isShadow: true);
                     }).toList() ?? [],
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBg, // Solid color for better visibility
                    borderRadius: BorderRadius.circular(20), // More rounded like a button
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 14, color: badgeText), // Solid color
                      const SizedBox(width: 4),
                      Text(
                        'วิเคราะห์',
                        style: GoogleFonts.kanit(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold, 
                          color: badgeText // Solid color
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildScoreCircle(dynamic score, Color color, {bool isShadow = false}) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: isShadow ? Border.all(color: Colors.white.withOpacity(0.5), width: 1) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: GoogleFonts.kanit(
          color: Colors.white, 
          fontWeight: FontWeight.w900, 
          fontSize: 11,
          shadows: [
            const Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTop4SkeletonGrid() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 310,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 2.5),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Top Row
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildSingleSkeletonCard()),
                      Container(width: 2, color: Colors.grey[200]),
                      Expanded(child: _buildSingleSkeletonCard()),
                    ],
                  ),
                ),
                Container(height: 2, color: Colors.grey[200]),
                // Bottom Row
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildSingleSkeletonCard()),
                      Container(width: 2, color: Colors.grey[200]),
                      Expanded(child: _buildSingleSkeletonCard()),
                    ],
                  ),
                ),
              ],
            ),
            // Loading Bar Overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: (_isNamesLoading || _isLoading || _isTop4Switching) 
               ? const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  minHeight: 2.5,
                )
               : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSkeletonCard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Container(width: 80, height: 20, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
          ],
        ),
        const SizedBox(height: 8),
        Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Container(width: 1.5, height: 20, color: Colors.grey[200]),
            const SizedBox(width: 12),
            Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)),
          ],
        ),
      ],
    );
  }

  Future<void> _showLinguisticAnalysis() async {
    String name = _nameController.text;
    if (_analysisResult != null && _analysisResult!['solar_system'] != null) {
       name = _analysisResult!['solar_system']['cleaned_name'] ?? name;
    }
    
    if (name.trim().isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาระบุชื่อเพื่อวิเคราะห์')));
       return;
    }

    bool isCancelled = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) isCancelled = true;
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              const SizedBox(height: 24),
              Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    Text(
                      'โปรดรอสักครู่...',
                      style: GoogleFonts.kanit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'กำลังค้นหารากศัพท์และวิเคราะห์ภาษา...',
                      style: GoogleFonts.kanit(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  isCancelled = true;
                  Navigator.of(dialogContext).pop();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: Text('ยกเลิกการรอ', style: GoogleFonts.kanit(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await ApiService.analyzeLinguistically(name);
      
      if (!mounted || isCancelled) return;

      // Close loading dialog if it hasn't been closed by the user
      Navigator.of(context).pop();

      // Dismiss keyboard before navigating
      FocusScope.of(context).unfocus();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LinguisticDetailPage(
            name: name,
            analysisHtml: result['analysis'] ?? 'ไม่มีข้อมูล',
          ),
        ),
      );
    } catch (e) {
      if (!mounted || isCancelled) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  Future<void> _saveCurrentName() async {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>;
    try {
      final msg = await ApiService.saveName(
        name: solar['cleaned_name'],
        day: solar['input_day_raw'],
        totalScore: solar['grand_total_score'],
        satSum: solar['total_numerology_value'],
        shaSum: solar['total_shadow_value'],
      );
      if (mounted) {
        // Signal Dashboard to refresh its data
        ApiService.dashboardRefreshSignal.value++;
        
        _showStyledDialog(
          title: 'สำเร็จ',
          message: '$msg\nคุณสามารถดูรายชื่อที่บันทึกไว้ได้ที่เมนู Dashboard',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          secondaryActionLabel: 'ไปที่ Dashboard',
          onSecondaryAction: () {
            // Use MainTabPage index 3 for Dashboard
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainTabPage(initialIndex: 3)),
              (route) => false,
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        // Check if it's a login required error
        if (errorMsg.contains('เข้าสู่ระบบ')) {
          _showLoginRequiredDialog();
        } else {
          _showStyledDialog(
            title: 'แจ้งเตือน',
            message: errorMsg,
            icon: Icons.info_outline,
            color: Colors.orange,
          );
        }
      }
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.orange),
            const SizedBox(width: 10),
            Text('กรุณาเข้าสู่ระบบ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('กรุณาเข้าสู่ระบบก่อนบันทึกชื่อ', style: GoogleFonts.kanit()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterPage()),
              );
            },
            child: Text('ลงทะเบียน', style: GoogleFonts.kanit(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('เข้าสู่ระบบ', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStyledDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.kanit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ตกลง', style: GoogleFonts.kanit(color: Colors.grey[600])),
          ),
          if (secondaryActionLabel != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (onSecondaryAction != null) onSecondaryAction();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(secondaryActionLabel, style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (mounted) {
      setState(() => _isLoggedIn = loggedIn);
    }
  }

  Future<void> _handleUnlockAction() async {
    if (!_isLoggedIn) {
       Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      ).then((_) {
         _checkLoginStatus(); 
         _onInputChanged();
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ShopPage()),
      ).then((_) {
         _onInputChanged();
      });
    }
  }

  void _showNumerologyDetail() {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>;
    final decodedParts = (solar['decoded_parts'] as List?) ?? [];
    final uniquePairs = (solar['all_unique_pairs'] as List?) ?? [];
    final name = solar['cleaned_name'];
    final isVip = _analysisResult!['is_vip'] == true;

    // Dismiss keyboard before navigating
    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NumerologyDetailPage(
          name: name ?? '',
          decodedParts: decodedParts,
          uniquePairs: uniquePairs,
          isVip: isVip,
          onUpgrade: _handleUnlockAction,
        ),
      ),
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isBad = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.kanit(
          fontSize: 14,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isBad ? Colors.red : Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('วิเคราะห์ชื่อ', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF333333),
        elevation: 0,
        scrolledUnderElevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ไม่มีการแจ้งเตือนใหม่')),
              );
            },
            tooltip: 'การแจ้งเตือน',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF667EEA).withOpacity(0.05),
              const Color(0xFF764BA2).withOpacity(0.03),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildSearchForm(),
            
            // Initial generic loading if nothing is ready yet (only used for very first entry)
            // Removed full-page spinner to allow skeletal UI below to show immediately

            // Results Section (Always present)
            _buildSampleNamesSection(),
            Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Bottom layer: Analysis Header + Table (will be behind planets)
                Column(
                  children: [
                    const SizedBox(height: 330), // Space for solar system
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: _analysisResult == null 
                          ? KeyedSubtree(key: const ValueKey('header_skeleton'), child: _buildSolarHeaderSkeleton())
                          : KeyedSubtree(key: const ValueKey('header_real'), child: _buildAnalysisHeader()),
                    ),

                    // Always show Top4 section if switching (with skeleton)
                    if (_isTop4Switching || _analysisResult != null) ...[
                       RepaintBoundary(
                         child: _buildTop4Section(),
                       ),
                    ],
                    
                    // Show table skeleton or real table
                    // Show table skeleton or real table
                    // Fix: Only use global skeleton if we have NO result yet.
                    // If we have result (reload), use _buildSimilarNamesTable which handles skeleton + toggles internally.
                    if (_analysisResult == null && _isNamesLoading) 
                       _buildTableSkeleton() 
                    else if (_analysisResult != null) ...[
                       _buildSimilarNamesTable(),
                    ]
                  ],
                ),
                // Top layer: Solar System (Planets)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _analysisResult == null
                        ? KeyedSubtree(key: const ValueKey('solar_skeleton'), child: _buildSolarSystemSkeleton())
                        : KeyedSubtree(
                            key: ValueKey('solar_${_analysisResult!['solar_system']['cleaned_name']}'), 
                            child: _buildSolarSystemSection()
                          ),
                  ),
                ),
              ],
            ),
            const SharedFooter(),
          ],
        ),
        ),
      ),
      floatingActionButton: _showScrollToTop 
         ? Padding(
             padding: const EdgeInsets.only(bottom: 90),
             child: FloatingActionButton(
                 onPressed: () {
                   _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
                 },
                 backgroundColor: Colors.white,
                 mini: true,
                 elevation: 4,
                 shape: const CircleBorder(),
                 child: const Icon(Icons.arrow_upward, color: Colors.blueGrey),
               ),
           ) 
         : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  Widget _buildSearchForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            onChanged: (_) {
              setState(() {}); // Update clear button visibility
              _onInputChanged();
            },
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\u0E00-\u0E7F]')),
            ],
            decoration: InputDecoration(
              labelText: 'กรอกชื่อที่ต้องการวิเคราะห์',
              hintText: 'เช่น ปัญญา, สมชาย',
              helperText: 'วิเคราะห์อัตโนมัติเมื่อพิมพ์ชื่อ',
              helperStyle: GoogleFonts.kanit(color: Colors.blueAccent),
              prefixIcon: const Icon(Icons.person_outline),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _nameController.clear();
                        });
                        _onInputChanged();
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedDay,
            decoration: InputDecoration(
              labelText: 'วันเกิด',
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: _days.map((day) {
              return DropdownMenuItem(
                value: day['value'] as String,
                child: Row(
                  children: [
                    Icon(day['icon'] as IconData, color: day['color'] as Color, size: 20),
                    const SizedBox(width: 10),
                    Text(day['label'] as String, style: GoogleFonts.kanit()),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedDay = val!);
              _onInputChanged();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            label: 'เลขศาสตร์',
            icon: Icons.assignment_outlined,
            color: const Color(0xFF4F46E5), // Indigo 600
            onTap: _showNumerologyDetail,
          ),
          _buildActionButton(
            label: 'ภาษาศาสตร์',
            icon: Icons.menu_book_outlined,
            color: const Color(0xFF0D9488), // Teal 600
            onTap: _showLinguisticAnalysis,
          ),
          _buildActionButton(
            label: 'บันทึก',
            icon: Icons.save_outlined,
            color: const Color(0xFF475569), // Slate 700 (More premium than plain grey)
            onTap: _saveCurrentName,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolarHeaderSkeleton() {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: const Center(child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
      ),
    );
  }

  Widget _buildSolarSystemSkeleton() {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Center(
        child: SizedBox(
          width: 320,
          height: 320,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 1; i <= 4; i++)
                Container(
                  width: 60.0 + (i * 65.0),
                  height: 60.0 + (i * 65.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.indigo.withOpacity(0.05), width: 1),
                  ),
                ),
              const Center(child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisHeader() {
    if (_analysisResult == null || _analysisResult!['solar_system'] == null) {
      return _buildSolarHeaderSkeleton();
    }
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>;
    final name = solar['cleaned_name'] ?? '';
    final sunDisplayNameHTML = (solar['sun_display_name_html'] as List?) ?? [];
    List<String> klakiniChars = (solar['klakini_chars'] as List?)?.map((e) => e.toString()).toList() ?? [];
    
    // UI Consistency Fix: If the API returns an empty klakini list but marks chars as 'bad' (red) 
    // in sun_display_name_html, we extract those chars to show in the badge correctly.
    if (klakiniChars.isEmpty) {
      for (var item in sunDisplayNameHTML) {
        if (item['is_bad'] == true) {
          String c = (item['char'] ?? '').toString().trim();
          if (c.isNotEmpty && !klakiniChars.contains(c)) {
            klakiniChars.add(c);
          }
        }
      }
    }

    final inputDay = solar['input_day_raw'] ?? '';

    return Transform.translate(
      offset: const Offset(0, -40),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0), // Removed bottom margin to touch next view
        child: CustomPaint(
          painter: SpeechBubblePainter(),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 42), // Extra bottom padding for tail
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Name and Toggles Row (Moved to Top)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: sunDisplayNameHTML.map((dc) {
                        return Text(
                          dc['char'] ?? '',
                          style: GoogleFonts.kanit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: dc['is_bad'] == true ? Colors.red : const Color(0xFF2D3748),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 4, offset:const Offset(0,2))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: Colors.blueAccent),
                              const SizedBox(width: 6),
                              Text(inputDay, style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                            ],
                          ),
                        ),
                        _buildKlakiniBadge(klakiniChars),

                      ],
                    ),
                    if (klakiniChars.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.kanit(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            const TextSpan(text: 'พยัญชนะหรือสระ'),
                            TextSpan(
                              text: 'สีแดง',
                              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: 'คือกาลกิณี'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          // 2. Main Action Buttons
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showNumerologyDetail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)], // Indigo 500 to 600
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_outlined, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text('เลขศาสตร์', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _showLinguisticAnalysis,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)], // Emerald 500 to 600
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF10B981).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.menu_book_outlined, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text('ภาษาศาสตร์', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),

          // 3. Category Nested Donut Chart
          if (solar['category_breakdown'] != null)
             Builder(
               builder: (context) {
                 final breakdown = solar['category_breakdown'] as Map<String, dynamic>;
                 final numPairs = (solar['numerology_pairs'] as List?)?.length ?? 0;
                 final shaPairs = (solar['shadow_pairs'] as List?)?.length ?? 0;
                 return Padding(
                   padding: const EdgeInsets.only(bottom: 24),
                   child: CategoryNestedDonut(
                     categoryBreakdown: breakdown,
                     totalPairs: numPairs + shaPairs,
                   ),
                 );
               },
             ),
        ],
      ),
     ),
    ),
   ));
  }

  Widget _buildHeaderActionButtonHorizontal({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.kanit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKlakiniBadge(List<String> chars) {
    if (chars.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 12, color: Colors.green),
            const SizedBox(width: 4),
            Text('ไม่มีกาลกิณี', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning, size: 12, color: Colors.red),
          const SizedBox(width: 4),
          Text(chars.join(' '), style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildToggleItemSmall({
    String? label,
    Widget? labelWidget,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 24,
          width: 32,
          child: Transform.scale(
            scale: 0.75, // Slightly larger for better touch target
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: activeColor,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey[300],
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ),
        const SizedBox(height: 2),
        labelWidget != null
            ? labelWidget
            : Text(
                label ?? '',
                style: GoogleFonts.kanit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: value ? activeColor : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
      ],
    );
  }

  Widget _buildSampleNamesSection() {
    return FutureBuilder<List<SampleName>>(
      future: _sampleNamesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildSampleNamesSkeleton();

        final samples = snapshot.data!;

        return Stack(
          children: [
            Container(
              height: 90,
              padding: const EdgeInsets.only(top: 10),
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: samples.length,
                itemBuilder: (context, index) {
                  final sample = samples[index];
                  final isActive = _nameController.text.trim() == sample.name.trim();

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _nameController.text = sample.name;
                      });
                      _analyze();
                    },
                    child: Padding(
                       padding: const EdgeInsets.only(right: 16),
                       child: Column(
                         children: [
                           Container(
                             width: 50,
                             height: 50,
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               border: Border.all(
                            color: isActive ? Colors.orange : Colors.grey[200]!,
                            width: 2,
                          ),
                          image: DecorationImage(
                            image: NetworkImage(
                              sample.avatarUrl.startsWith('http')
                                  ? sample.avatarUrl
                                  : '${ApiService.baseUrl}${sample.avatarUrl}',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sample.name,
                        style: GoogleFonts.kanit(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? Colors.orange : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
            // Right Fade Gradient to indicate scroll
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSampleNamesSkeleton() {
    return Container(
      height: 90,
      padding: const EdgeInsets.only(top: 10),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              ),
              const SizedBox(height: 8),
              Container(width: 40, height: 8, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolarSystemSection() {
    if (_analysisResult == null || _analysisResult!['solar_system'] == null) {
      return _buildSolarSystemSkeleton();
    }
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>;
    final name = solar['cleaned_name'] ?? '';
    final sunDisplayNameHTML = (solar['sun_display_name_html'] as List?) ?? [];
    final isSunDead = solar['is_sun_dead'] == true;

    // Calculate Scores for Side Panel
    final numPos = solar['num_positive_score'] as int? ?? 0;
    final shaPos = solar['sha_positive_score'] as int? ?? 0;
    final numNeg = solar['num_negative_score'] as int? ?? 0;
    final shaNeg = solar['sha_negative_score'] as int? ?? 0;
    
    final totalPos = numPos + shaPos;
    final totalNeg = numNeg + shaNeg;
    final grandTotal = solar['grand_total_score'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT PANEL: Scores & Save
          Container(
            padding: const EdgeInsets.only(left: 16, right: 16), // Added left padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, // Left align text
              children: [
                // Total Score Label
                Text(
                  'คะแนนรวม',
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Total Score Value
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFD4AF37), size: 24), // Trophy
                    const SizedBox(width: 4),
                    Text(
                      '${grandTotal > 0 ? "+" : ""}$grandTotal',
                      style: GoogleFonts.kanit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: grandTotal >= 0 ? const Color(0xFF00C853) : const Color(0xFFFF3D00), // Bright Green or Red
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Positive/Negative Pills in ROW
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // Positive Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Reduced padding
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), // Light Green
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'ดี +$totalPos',
                        style: GoogleFonts.kanit(
                          fontSize: 12, // Reduced font size
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    // Negative Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Reduced padding
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE), // Light Red
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'ร้าย $totalNeg',
                        style: GoogleFonts.kanit(
                          fontSize: 12, // Reduced font size
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFC62828),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                // Save Button (Orange Gradient)
                InkWell(
                  onTap: _saveCurrentName,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                       gradient: const LinearGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFFFCA28)], // Amber/Orange Gradient
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'บันทึกชื่อ',
                          style: GoogleFonts.kanit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // RIGHT PANEL: Solar System Stack
          Flexible(
            child: SizedBox(
              width: 280, // Slightly smaller to fit side by side
              height: 280,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Orbits (Static)
                  CustomPaint(painter: OrbitPainter(), size: const Size(280, 280)),
                  
                  // Planets (Animated)
                  _buildPlanets((solar['shadow_pairs'] as List?) ?? [], 120, _rotationControllerOuter, false),
                  _buildPlanets((solar['numerology_pairs'] as List?) ?? [], 80, _rotationController, false),

                  // Sun (Static)
                  Container(
                    width: 100, // Smaller Sun
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSunDead ? Colors.grey[600] : const Color(0xFFFFD700),
                      boxShadow: isSunDead ? [] : [
                        BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
                        BoxShadow(color: const Color(0xFFFFA500).withOpacity(0.3), blurRadius: 40, spreadRadius: 10),
                      ],
                    ),
                    padding: const EdgeInsets.all(5),
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: sunDisplayNameHTML.map((dc) {
                          return Text(
                            dc['char'] ?? '',
                            style: GoogleFonts.kanit(
                              fontSize: name.length > 5 ? 14 : 18,
                              fontWeight: FontWeight.bold,
                              color: dc['is_bad'] == true ? const Color(0xFFFF4757) : (isSunDead ? Colors.grey[300] : const Color(0xFFB8860B)), // Matching Web Colors
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanets(List pairs, double radius, AnimationController controller, bool reverse) {
    if (pairs.isEmpty) return const SizedBox();
    
    final angleStep = (2 * math.pi) / pairs.length;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final rotationValue = controller.value * 2 * math.pi * (reverse ? -1 : 1);
        
        return Stack(
          children: pairs.asMap().entries.map((entry) {
            final idx = entry.key;
            final pair = entry.value;
            final angle = rotationValue + (idx * angleStep);
            
            final color = _getPairColor(pair['meaning']?['pair_type'] ?? '');

            return Positioned(
              left: 140 + radius * math.cos(angle) - 18, // Center is 140 for 280 size
              top: 140 + radius * math.sin(angle) - 18,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
                ),
                child: Center(
                  child: Text(
                    pair['pair_number'] ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildScoreSummary() {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>? ?? {};
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildScoreColumn('เลขศาสตร์', solar['total_numerology_value'] ?? 0, solar['num_positive_score'] ?? 0, solar['num_negative_score'] ?? 0),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              _buildScoreColumn('พลังเงา', solar['total_shadow_value'] ?? 0, solar['sha_positive_score'] ?? 0, solar['sha_negative_score'] ?? 0),
            ],
          ),
          const Divider(height: 32),
          Text(
            'คะแนนรวมความแม่นยำ: ${solar['grand_total_score'] ?? 0}',
            style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D3748)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreColumn(String title, int total, int pos, int neg) {
    return Column(
      children: [
        Text(title, style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text('$total', style: GoogleFonts.kanit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF2D3748))),
        Row(
          children: [
            Text('+$pos', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('$neg', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildMeaningsSection() {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>? ?? {};
    final uniquePairs = (solar['all_unique_pairs'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('คำทำนายภาพรวม', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...uniquePairs.map((p) => _buildMeaningItem(p)).toList(),
        ],
      ),
    );
  }

  Widget _buildMeaningItem(Map p) {
    final color = _getPairColor(p['meaning']['pair_type']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(p['pair_number'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['meaning']['miracle_desc'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(p['meaning']['miracle_detail'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarNamesTable() {
    final names = (_analysisResult!['similar_names'] as List?) ?? [];
    final isVip = _analysisResult!['is_vip'] == true;
    // Allow rendering if loading to show skeleton and toggles
    // Allow rendering if loading to show skeleton and toggles
    // Removed early return to ensure Toggles always show


    // VIP Banners
    Widget? vipBanner;
    if (!isVip) {
      vipBanner = Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFDB931)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
              child: const Icon(Icons.star, color: Color(0xFF4A3B00)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('รับรหัส VIP วิเคราะห์ +3 แสนชื่อเมื่อซื้อเบอร์มงคล', style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF4A3B00))),
                  // Subtitle removed to match user request for single string
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _handleUnlockAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(_isLoggedIn ? 'ร้านมาดี' : 'เข้าสู่ระบบ', style: GoogleFonts.kanit()),
            ),
          ],
        ),
      );
    } else {
       vipBanner = Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text('คุณกำลังใช้งานเวอร์ชัน VIP', style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF475569))),
          ],
        ),
      );
    }

    List<TableRow> tableRows = [];

    // Table Header
    tableRows.add(
      TableRow(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
        ),
        children: [
          _buildTableHeaderCell('ชื่อดี', alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 16)),
          _buildTableHeaderCell('เลขศาสตร์'),
          _buildTableHeaderCell('พลังเงา'),
          _buildTableHeaderCell('คะแนน'),
          _buildTableHeaderCell('คล้าย'),
          _buildTableHeaderCell(''),
        ],
      ),
    );

    // Table Body & Lock Logic
    bool showLockMessage = false;
    int limit = isVip ? names.length : 3;

    for (int i = 0; i < names.length; i++) {
        if (i < limit) {
             tableRows.add(_buildNameTableRow(names[i], i));
        } else {
            showLockMessage = true;
            break;
        }
    }

    return Transform.translate(
      offset: const Offset(0, -40),
      child: Container(
        color: Colors.white,
        child: Material(
            type: MaterialType.transparency,
            child: Column(
            children: [

              if (vipBanner != null) vipBanner,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildToggleItemSmall(
                      labelWidget: Text('ชื่อดีเท่านั้น', style: GoogleFonts.kanit(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
                      value: _isAuspicious,
                      activeColor: Colors.green,
                      onChanged: (val) {
                        setState(() => _isAuspicious = val);
                        _onInputChanged();
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildToggleItemSmall(
                      labelWidget: RichText(
                        text: TextSpan(
                          style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.normal),
                          children: [
                            const TextSpan(text: 'แสดง'),
                            TextSpan(text: 'กาลกิณี', style: TextStyle(color: Colors.red[700])),
                          ],
                        ),
                      ),
                      value: _showKlakini,
                      activeColor: const Color(0xFF388E3C),
                      onChanged: (val) {
                        setState(() => _showKlakini = val);
                        _onInputChanged();
                      },
                    ),
                  ],
                ),
              ),
              _isNamesLoading 
                  ? _buildTableSkeleton()
                  : (names.isEmpty 
                      ? Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Text('ไม่พบรายชื่อที่ใกล้เคียง', style: GoogleFonts.kanit(color: Colors.grey))) 
                      : Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2.5), // Name
                            1: FlexColumnWidth(1.5),  // Sat
                            2: FlexColumnWidth(1.5),  // Sha
                            3: FlexColumnWidth(1.2),  // Score
                            4: FlexColumnWidth(1.2),  // Similarity
                            5: FixedColumnWidth(30),  // Icon
                          },
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: tableRows,
                        )
                    ),
              
               if (!isVip && !showLockMessage && names.length <= 3 && names.isNotEmpty && !_isNamesLoading)
                 Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDE7),
                      border: Border(
                         top: BorderSide(color: const Color(0xFFFBC02D).withOpacity(0.3)),
                      ),
                    ),
                    child: Column(
                      children: [
                         Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'ชื่อดีล็อกแสดง 3 รายชื่อเท่านั้น',
                              style: GoogleFonts.kanit(color: const Color(0xFFF57F17), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                         SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: _handleUnlockAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF57F17),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: Text(_isLoggedIn ? 'ซื้อสินค้าร้านมาดี' : 'เข้าสู่ระบบ', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                 ),
              if (showLockMessage)
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDE7),
                    border: Border.all(color: const Color(0xFFFBC02D), style: BorderStyle.none),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock_outline, color: Color(0xFFF57F17), size: 28),
                      const SizedBox(height: 12),
                      Text(
                        'ชื่อดีถูกล็อกแสดงแค่ 3 รายชื่อเท่านั้น',
                        style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFFF57F17)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _handleUnlockAction,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          _isLoggedIn ? 'ซื้อสินค้าร้านมาดี' : 'เข้าสู่ระบบเพื่อดูเพิ่มเติม',
                          style: GoogleFonts.kanit(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, {Alignment alignment = Alignment.center, EdgeInsets padding = EdgeInsets.zero}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12).add(padding),
      alignment: alignment,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.kanit(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4A5568),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  TableRow _buildNameTableRow(Map n, int index) {
    final isPremium = n['is_top_tier'] == true;
    final displayName = n['display_name_html'] as List;
    final similarity = (n['similarity'] as num? ?? 0) * 100;

    final onTap = () {
      _nameController.text = n['th_name'];
      _analyze();
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    };

    return TableRow(
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFFFFFDE7) : Colors.transparent,
        border: Border(
           bottom: BorderSide(color: isPremium ? const Color(0xFFFBC02D) : const Color(0xFFF0F4F8), width: isPremium ? 2 : 1),
        ),
      ),
      children: [
        // Name Cell
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                // Rank and Premium Star stacked vertically to save horizontal space
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPremium)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _buildPremiumStar(12),
                      ),
                    Text(
                      '#${index + 1}',
                      style: GoogleFonts.kanit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    children: [
                      ...displayName.map((dc) => Text(
                        dc['char'] ?? '',
                        style: GoogleFonts.kanit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: dc['is_bad'] == true ? const Color(0xFFFF4757) : const Color(0xFFC59D00),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Sat Cell
        InkWell(
          onTap: onTap,
          child: Container(
             padding: const EdgeInsets.symmetric(vertical: 14),
             child: _buildPairBadgeRow(n['t_sat'] as List, n['sat_num'] as List)
          ),
        ),
        // Sha Cell
        InkWell(
          onTap: onTap,
          child: Container(
             padding: const EdgeInsets.symmetric(vertical: 14),
             child: _buildPairBadgeRow(n['t_sha'] as List, n['sha_num'] as List)
          ),
        ),
        // Score Cell
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (n['total_score'] ?? 0) >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(n['total_score'] ?? 0) > 0 ? '+' : ''}${n['total_score']}',
                style: GoogleFonts.kanit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: (n['total_score'] ?? 0) >= 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ),
        ),
        // Similarity Cell
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              '${similarity.toStringAsFixed(0)}%',
              style: GoogleFonts.kanit(fontSize: 12, color: const Color(0xFFADB5BD)),
            ),
          ),
        ),
        // Icon Cell
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Icon(Icons.search, size: 16, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  Widget _buildPairBadgeRow(List pairs, List nums) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        children: pairs.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          return Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _parseColor(p['color'] ?? p['Color'])),
            child: Center(
              child: Text(
                '${nums[idx]}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getPairColor(String type) {
    switch (type) {
      case 'D10': return const Color(0xFF2E7D32);
      case 'D8': return const Color(0xFF43A047);
      case 'D5': return const Color(0xFF66BB6A);
      case 'R10': return const Color(0xFFC62828);
      case 'R7': return const Color(0xFFD32F2F);
      case 'R5': return const Color(0xFFE57373);
      default: return Colors.grey;
    }
  }

  Widget _buildTableSkeleton() {
    return Stack(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 400), // Prevent collapse
          child: Column(
            children: List.generate(5, (index) => 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 100, 
                      height: 20, 
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 20, 
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))
                      )
                    ),
                  ],
                ),
              )
            ),
          ),
        ),
        // Loading Bar Overlay
        if (_isNamesLoading || _isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.withOpacity(0.8)),
              minHeight: 3,
            ),
          ),
      ],
    );
  }
}

class OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 5, dashSpace = 5;
    final center = Offset(size.width / 2, size.height / 2);

    void drawDashedCircle(double radius) {
      final circumference = 2 * math.pi * radius;
      final totalSteps = (circumference / (dashWidth + dashSpace)).floor();
      for (int i = 0; i < totalSteps; i++) {
        final startAngle = (i * (dashWidth + dashSpace) / radius);
        final sweepAngle = dashWidth / radius;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
      }
    }

    drawDashedCircle(80);
    drawDashedCircle(120);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpeechBubblePainter extends CustomPainter {
  final Color color;
  final Color shadowColor;

  SpeechBubblePainter({this.color = Colors.white, this.shadowColor = const Color(0x0D000000)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    const radius = 20.0;
    const tailWidth = 24.0;
    const tailHeight = 12.0;

    // Main Box (adjusted height to leave space for tail)
    final boxRect = RRect.fromLTRBAndCorners(
      0, 0, size.width, size.height - tailHeight,
      topLeft: const Radius.circular(radius),
      topRight: const Radius.circular(radius),
      bottomLeft: const Radius.circular(radius),
      bottomRight: const Radius.circular(radius),
    );
    
    path.addRRect(boxRect);

    // Tail (Bottom Center)
    path.moveTo(size.width / 2 - tailWidth / 2, size.height - tailHeight);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 + tailWidth / 2, size.height - tailHeight);
    path.close();

    // Draw Shadow
    canvas.drawPath(path, shadowPaint);
    
    // Draw Background
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 5, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1.5;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
