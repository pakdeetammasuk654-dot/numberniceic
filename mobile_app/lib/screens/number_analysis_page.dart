import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/shared_footer.dart';
import '../widgets/premium_donut_chart.dart';
import '../widgets/wreath_score_grid.dart';
import '../widgets/solar_system_widget.dart';
import '../services/api_service.dart';
import 'vip_grade_info_page.dart';
import 'main_tab_page.dart';

class NumberAnalysisPage extends StatefulWidget {
  final bool isBottomSheet;
  final String? initialPhoneNumber;
  const NumberAnalysisPage({super.key, this.isBottomSheet = false, this.initialPhoneNumber});

  static Future<void> show(BuildContext context, {String? phoneNumber}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NumberAnalysisPage(isBottomSheet: true, initialPhoneNumber: phoneNumber),
    );
  }

  @override
  State<NumberAnalysisPage> createState() => _NumberAnalysisPageState();
}

class _NumberAnalysisPageState extends State<NumberAnalysisPage> with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  bool _isLoading = false;
  Map<String, dynamic>? _analysisData;
  int _analyzeCount = 0; // For forcing animation transition

  late AnimationController _innerOrbitController;
  late AnimationController _outerOrbitController;
  AnimationController? _textShineController;

  @override
  void initState() {
    super.initState();
    
    String startNumber = '0936544442'; // Default requested by user
    
    if (widget.initialPhoneNumber != null) {
      startNumber = widget.initialPhoneNumber!;
    }
    
    _phoneController.text = startNumber;
    
    // Auto-analyze default or initial number
    if (startNumber.isNotEmpty) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
          _analyzeNumber(startNumber);
       });
    }

    // Inner Orbit: 20s
    _innerOrbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Outer Orbit: 30s
    _outerOrbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Text Shine: 2s (Initialized here for fresh starts)
    _textShineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    // Allow override if empty OR if it holds the default value
    if (args is String && args.length == 10 && (_phoneController.text.isEmpty || _phoneController.text == '0936544442')) {
      _phoneController.text = args;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _analyzeNumber(args);
      });
    }
    
    // Lazy init for Hot Reload support
    if (_textShineController == null) {
      _textShineController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _innerOrbitController.dispose();
    _outerOrbitController.dispose();
    _textShineController?.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    if (value.length == 10) {
      FocusScope.of(context).unfocus();
      _analyzeNumber(value);
    } else {
      if (_analysisData != null) {
        setState(() {
          _analysisData = null;
        });
      }
    }
  }

  Future<void> _analyzeNumber(String number) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.analyzeRawNumber(number);
      setState(() {
        _analysisData = data;
        _analyzeCount++; // Force animation update
      });
    } catch (e) {
      print('Analysis Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isGoodColor(String? color) {
    if (color == null) return false;
    final c = color.replaceAll('#', '').toUpperCase();
    // Green shades from backend/frontend
    const goodColors = ['2E7D32', '43A047', '66BB6A', '10B981', '0D9488', '14B8A6'];
    return goodColors.any((gc) => c.contains(gc));
  }

  @override
  Widget build(BuildContext context) {
    // Determine Grade Logic
    String? gradeTitle;
    bool showGoldenBadge = false;

    if (_analysisData != null) {
      final mainPairs = _analysisData!['main_pairs'] as List?;
      final sumMeaning = _analysisData!['sum_meaning'];
      
      if (sumMeaning != null && _isGoodColor(sumMeaning['meaning']?['color'])) {
          int consecutive = 0;
          if (mainPairs != null) {
             // Check from end to start
             for (int i = mainPairs.length - 1; i >= 0; i--) {
                if (_isGoodColor(mainPairs[i]['meaning']?['color'])) {
                   consecutive++;
                } else {
                   break;
                }
             }
          }

          if (consecutive == 0) {
             gradeTitle = "ผลรวมดี";
             showGoldenBadge = true;
          } else if (consecutive == 1) {
             gradeTitle = "คู่ท้ายดี";
             showGoldenBadge = true;
          } else if (consecutive == 2) {
             gradeTitle = "คู่ท้าย Double ดี";
             showGoldenBadge = true;
          } else if (consecutive == 3) {
             gradeTitle = "Triple ดี";
             showGoldenBadge = true;
          } else if (consecutive == 4) {
             gradeTitle = "The Best";
             showGoldenBadge = true;
          } else if (consecutive >= 5) {
             gradeTitle = "PERFECT";
             showGoldenBadge = true;
          }
      }
    }

    final content = Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
         title: Text('วิเคราะห์เบอร์โทรศัพท์', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
         backgroundColor: const Color(0xFF333333),
         elevation: 0,
         centerTitle: true,
         leading: widget.isBottomSheet 
            ? IconButton(
                icon: const Icon(Icons.expand_more, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              )
            : null,
         actions: [
            if (!widget.isBottomSheet)
              IconButton(
                icon: const Icon(Icons.dialpad, color: Color(0xFFFFD700)),
                onPressed: () {},
                tooltip: 'วิเคราะห์เบอร์',
              ),
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // White Header Section (Clean & Minimalist like Web)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0), // Fix: Remove top padding (16->0) to touch edge
              color: Colors.transparent, // Transparent to show scaffold bg
              child: Column(
                children: [
                  
                  // Beautiful Input Form (Added as requested)
                  Container(
                      margin: const EdgeInsets.symmetric(vertical: 24), 
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                           colors: [Color(0xFFFFD700), Color(0xFFFF8F00)], // Gold Gradient Border
                           begin: Alignment.topLeft, end: Alignment.bottomRight
                        ), 
                        boxShadow: [
                           BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
                        ]
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.dialpad, color: Color(0xFFFFB300)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                style: GoogleFonts.kanit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF333333), height: 1.2),
                                decoration: InputDecoration(
                                  hintText: 'กรอกเบอร์มือถือ',
                                  hintStyle: GoogleFonts.kanit(color: Colors.grey[300], fontSize: 20),
                                  border: InputBorder.none,
                                  counterText: "",
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                   setState(() {}); // Rebuild to show/hide Update Clear Button
                                   if (val.length == 10) {
                                      _analyzeNumber(val);
                                      FocusScope.of(context).unfocus();
                                   }
                                },
                                onSubmitted: (val) => _analyzeNumber(val),
                              ),
                            ),
                            
                            // Clear Button (Show only when not empty)
                            if (_phoneController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _phoneController.clear();
                                    _analysisData = null; // Optional: Reset analysis when cleared?
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                ),
                              ),

                            if (_isLoading)
                               const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFFFFB300))))
                            else
                               InkWell(
                                  onTap: () {
                                     if (_phoneController.text.isNotEmpty) _analyzeNumber(_phoneController.text);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(color: Color(0xFFFFF8E1), shape: BoxShape.circle),
                                    child: const Icon(Icons.search_rounded, color: Color(0xFFFFB300)),
                                  ),
                               )
                          ],
                        ),
                      ),
                    ),

                // Animated Content Switching (Fade In/Out with Stack)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 1000), // 1 Second Duration
                  switchInCurve: Curves.easeOutBack, // Bouncy/Smooth in
                  switchOutCurve: Curves.easeInBack,
                  // IMPORTANT: Stack children to allow true Cross-Fade
                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  // Scale + Fade Transition
                  transitionBuilder: (Widget child, Animation<double> animation) {
                     return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                           scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), // Subtle Pop
                           child: child,
                        ),
                     );
                  },
                  child: _isLoading 
                    ? Container(
                        key: const ValueKey('loading'),
                        margin: const EdgeInsets.only(top: 40),
                        child: const CircularProgressIndicator(color: Color(0xFFFFD700)),
                      )
                    : (_analysisData == null && _phoneController.text.isEmpty)
                        ? Padding(
                            key: const ValueKey('empty'),
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'ไม่พบเบอร์โทรศัพท์\nกรุณาเลือกเบอร์จากหน้าหลัก',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.kanit(fontSize: 18, color: Colors.grey[400]),
                            ),
                          )
                        : _analysisData != null 
                            ? Column(
                                // Use _analyzeCount to FORCE animation on every new result
                                key: ValueKey('data_$_analyzeCount'), 
                                children: [
                                  const SizedBox(height: 8),
                                  
                                  SolarSystemWidget(
                                    sumPair: _analysisData!['sum_meaning'],
                                    mainPairs: _analysisData!['main_pairs'] as List?,
                                    hiddenPairs: _analysisData!['hidden_pairs'] as List?,
                                  ),

                                  const SizedBox(height: 8), 

                                  if (showGoldenBadge && gradeTitle != null) ...[
                                    _buildGradeBadge(_phoneController.text, gradeTitle!),
                                    const SizedBox(height: 16),
                                  ],
                                  
                                  const SizedBox(height: 8),
                                ],
                              )
                            : const SizedBox(key: ValueKey('blank')),
                ),
                // Add spacer to push footer down if content is short (since we used Stack alignment)
                // Removed fixed spacer to fix large gap
              ],
            ),
          ),
          
          // 3. Meaning Analysis Section (Full Width)
          if (!_isLoading && _analysisData != null)
             _buildMeaningSection(_analysisData!),

          const SizedBox(height: 40),
          
          // MOVED: Footer is now outside the padded container to span full width
          const SharedFooter(),
        ],
      ),
    ),
  );

    if (widget.isBottomSheet) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Color(0xFFFAFAFA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: content,
      );
    }

    return content;
  }

  Widget _buildGradeBadge(String phoneNumber, String title) {
    return Column(
      children: [
        // 1. Golden Glowing Animated Phone Number
        AnimatedBuilder(
          animation: _textShineController!,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: const [
                    Color(0xFFAA771C), // Darker
                    Color(0xFFFCF6BA), // Light
                    Color(0xFFFFFFFF), // Shimmer White
                    Color(0xFFFCF6BA), // Light
                    Color(0xFFAA771C), // Darker
                  ],
                  stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                  // Move the gradient from left to right
                  begin: Alignment(-2.0 + (_textShineController!.value * 4), 0.0),
                  end: Alignment(-0.5 + (_textShineController!.value * 4), 0.0),
                  tileMode: TileMode.clamp,
                ).createShader(bounds);
              },
              child: Text(
                phoneNumber,
                style: GoogleFonts.kanit(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                  shadows: [
                     Shadow(
                       color: Colors.amber.withOpacity(0.5),
                       blurRadius: 15,
                       offset: const Offset(0, 0),
                     ),
                  ]
                ),
              ),
            );
          },
        ),

        // Reduced spacing to keep it tight
        const SizedBox(height: 0), // Reduced 12 -> 0 to bring Title closer to Number

        // 2. Title (PERFECT) + Stars
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VipGradeInfoPage()),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFF92400E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.kanit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white, // Masked
                        height: 1.0, 
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.star, color: const Color(0xFFF59E0B), size: index == 2 ? 28 : 22),
                  )
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 8), // Reduced 16 -> 8

        // 3. Buy Button (Moved to new line for better layout)
        ElevatedButton(
          onPressed: () {
            // Show Contact Dialog
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
                                        animation: _textShineController!,
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
                                                begin: Alignment(-2.0 + (_textShineController!.value * 4), 0.0),
                                                end: Alignment(-0.5 + (_textShineController!.value * 4), 0.0),
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
                                                   // Subtle sharp shadow for readability instead of broad glow
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
                },
                style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF10B981), // Emerald Green
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                   ),
                   elevation: 4,
                ),
                child: Text(
                   "ซื้อเบอร์นี้",
                   style: GoogleFonts.kanit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                   ),
                ),
             ),
      ],
    );
  }

  Widget _buildMeaningSection(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      // Remove margin to span full width
      margin: EdgeInsets.zero, 
      decoration: BoxDecoration(
        color: Colors.white,
        // Remove border radius to align edges
        borderRadius: BorderRadius.zero, 
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)), // Shadow pointing up slightly
        ],
        // Only keep top/bottom borders if needed, or remove completely
        border: const Border(
          top: BorderSide(color: Color(0xFFEEEEEE)),
          bottom: BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.description, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text(
                  'คำทำนายและความหมาย',
                  style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          Padding(
             padding: const EdgeInsets.all(16),
             child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SUM
                  if (data['sum_meaning'] != null) ...[
                     _SectionHeader(icon: Icons.functions, title: 'ผลรวม (SUM)', color: const Color(0xFFD97706)),
                     const SizedBox(height: 8),
                     _MeaningCard(
                       item: data['sum_meaning'], 
                       isSum: true,
                       onDismissKeyboard: () => _phoneFocusNode.unfocus(),
                     ),
                     const SizedBox(height: 24),
                  ],

                  // MAIN PAIRS
                  _SectionHeader(icon: Icons.verified_user, title: 'คู่เลขหลัก (MAIN PAIRS)', color: const Color(0xFF4F46E5)),
                  const SizedBox(height: 8),
                  if (data['main_pairs'] != null)
                    ...(data['main_pairs'] as List).map((p) => _MeaningCard(
                      item: p,
                      onDismissKeyboard: () => _phoneFocusNode.unfocus(),
                    )),
                  
                  const SizedBox(height: 24),

                  // HIDDEN PAIRS
                  _SectionHeader(icon: Icons.visibility_off, title: 'คู่เลขแฝง (HIDDEN PAIRS)', color: const Color(0xFF6B7280)),
                  const SizedBox(height: 8),
                  if (data['hidden_pairs'] != null)
                    ...(data['hidden_pairs'] as List).map((p) => _MeaningCard(
                      item: p,
                      onDismissKeyboard: () => _phoneFocusNode.unfocus(),
                    )),
                ],
             ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title, style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _MeaningCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isSum;
  final VoidCallback? onDismissKeyboard;

  const _MeaningCard({required this.item, this.isSum = false, this.onDismissKeyboard});

  @override
  Widget build(BuildContext context) {
    final pair = item['pair']?.toString() ?? '';
    final meaning = item['meaning'] as Map<String, dynamic>?;
    final colorHex = meaning?['color']?.toString() ?? '#9E9E9E';
    final desc = meaning?['miracle_desc']?.toString() ?? '-';
    final detail = meaning?['miracle_detail']?.toString() ?? '';
    final keywords = (meaning?['keywords'] as List?)?.join(' / ');
    
    final color = _parseColor(colorHex);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Dismiss keyboard before showing detail
          onDismissKeyboard?.call();
          
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _MeaningDetailSheet(
              pair: pair,
              color: color,
              keywords: keywords ?? '',
              desc: desc,
              detail: detail,
            ),
          ).then((_) {
            // Ensure keyboard stays dismissed after closing bottom sheet
            onDismissKeyboard?.call();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSum ? const Color(0xFFFFFBEB) : Colors.white,
            border: Border.all(color: isSum ? const Color(0xFFFEF3C7) : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSum ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset:const Offset(0,2))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                width: 36, height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                   color: color,
                   shape: BoxShape.circle,
                   boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0,2))]
                ),
                child: Text(
                  pair, 
                  style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)
                ),
              ),
              const SizedBox(width: 12),
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (keywords != null && keywords.isNotEmpty)
                       Text(
                         keywords,
                         style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))
                       ),
                    Text(
                      desc,
                      style: GoogleFonts.kanit(fontSize: 12, color: const Color(0xFF6B7280)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
     try {
       String clean = hex.replaceAll('#', '');
       if (clean.length == 6) clean = 'FF$clean';
       return Color(int.parse(clean, radix: 16));
     } catch(e) {
       return Colors.grey;
     }
  }
}

class _MeaningDetailSheet extends StatelessWidget {
  final String pair;
  final Color color;
  final String keywords;
  final String desc;
  final String detail;

  const _MeaningDetailSheet({
    required this.pair,
    required this.color,
    required this.keywords,
    required this.desc,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Big Badge
                  Container(
                    width: 80, height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
                      ]
                    ),
                    child: Text(
                      pair,
                      style: GoogleFonts.kanit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (keywords.isNotEmpty) ...[
                    Text(
                      keywords,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF4B5563)),
                  ),
                  
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 20, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 8),
                              Text(
                                'คำทำนายเจาะลึก',
                                style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "     " + detail, // Added indentation using spaces
                            style: GoogleFonts.sarabun( // Changed to Sarabun
                                fontSize: 18, // Increased size
                                color: const Color(0xFF374151), 
                                height: 1.6
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SolarSystem extends StatelessWidget {
  final Map<String, dynamic> data;
  final AnimationController innerController;
  final AnimationController outerController;

  const _SolarSystem({required this.data, required this.innerController, required this.outerController});

  @override
  Widget build(BuildContext context) {
    // Sum Badge (Sun)
    final sumPair = data['sum_meaning']?['pair']?.toString() ?? '00';
    final sumColor = _parseColor(data['sum_meaning']?['meaning']?['color']);

    final mainPairs = (data['main_pairs'] as List?) ?? [];
    final hiddenPairs = (data['hidden_pairs'] as List?) ?? [];

    return SizedBox(
      width: 300, 
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
           // Sun
           Container(
             width: 100, height: 100,
             decoration: BoxDecoration(
               color: const Color(0xFFFFD700),
               shape: BoxShape.circle,
               boxShadow: [
                 BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
               ]
             ),
             alignment: Alignment.center,
             child: Container(
               width: 44, height: 44,
               decoration: BoxDecoration(
                 color: sumColor,
                 shape: BoxShape.circle,
                 border: Border.all(color: Colors.white, width: 2),
                 boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)]
               ),
               alignment: Alignment.center,
               child: Text(sumPair, style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold))
             ),
           ),

           // Orbits
           _buildOrbit(160, Colors.orange.withOpacity(0.3)),
           _buildOrbit(260, Colors.orange.withOpacity(0.2)),

           // Inner Planets (Main Pairs)
           ...List.generate(mainPairs.length, (index) {
              return _Planet(
                controller: innerController, 
                index: index, 
                total: mainPairs.length, 
                radius: 80, // 160/2 
                item: mainPairs[index],
                isReverse: false,
              );
           }),

           // Outer Planets (Hidden Pairs)
           ...List.generate(hiddenPairs.length, (index) {
              return _Planet(
                controller: outerController, 
                index: index, 
                total: hiddenPairs.length, 
                radius: 130, // 260/2
                item: hiddenPairs[index],
                isReverse: false, // Web logic: planets counter-rotate, but here we orbit
                // Actually web: container spins, planets anti-spin to stay upright.
                // Simplified: Just orbit them. Text rotation correction handled in _Planet if needed.
              );
           }),
           
           // Legend
           Positioned(
             bottom: 0,
             child: Text('วงใน: คู่เลขหลัก | วงนอก: คู่เลขแฝง', style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[500])),
           )
        ],
      ),
    );
  }

  Widget _buildOrbit(double diameter, Color color) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, style: BorderStyle.solid, width: 1), // Dashed hard in basic container, solid fine
      ),
    );
  }
  
  Color _parseColor(dynamic hex) {
     if (hex == null) return Colors.grey;
     try {
       String clean = hex.toString().replaceAll('#', '');
       if (clean.length == 6) clean = 'FF$clean';
       return Color(int.parse(clean, radix: 16));
     } catch(e) {
       return Colors.grey;
     }
  }
}

class _Planet extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int total;
  final double radius;
  final Map<String, dynamic> item;
  final bool isReverse;

  const _Planet({
    required this.controller, 
    required this.index, 
    required this.total, 
    required this.radius,
    required this.item,
    required this.isReverse
  });

  @override
  Widget build(BuildContext context) {
    final pair = item['pair']?.toString() ?? '';
    
    // Determine if this pair is bad
    bool isBad = false;
    final meaning = item['meaning'];
    if (meaning != null) {
      // Check is_bad flag
      final badVal = meaning['is_bad'];
      if (badVal is bool) {
        isBad = badVal;
      } else if (badVal is int) {
        isBad = badVal > 0;
      } else if (badVal is String) {
        isBad = badVal.toLowerCase() == 'true';
      }
      
      // Fallback: check pair_type if is_bad not set
      if (!isBad && meaning['pair_type'] != null) {
        final pairType = meaning['pair_type'].toString();
        isBad = (pairType == 'ร้าย' || pairType == 'ร้ายมาก');
      }
    }
    
    // Use green for good, red for bad
    final color = isBad ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    
    // Calculate initial angle based on index
    final double initialAngle = (2 * math.pi * index) / total;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Orbit rotation
        final double currentAngle = initialAngle + (controller.value * 2 * math.pi);
        
        // Polar to Cartesian
        final double x = radius * math.cos(currentAngle);
        final double y = radius * math.sin(currentAngle);

        return Transform.translate(
          offset: Offset(x, y),
          child: Container(
            width: 30, height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)]
            ),
            child: Text(pair, style: GoogleFonts.kanit(fontSize: 10, color: isBad ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => __BlinkingDotState();
}

class __BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10, height: 10,
        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
      ),
    );
  }
}
