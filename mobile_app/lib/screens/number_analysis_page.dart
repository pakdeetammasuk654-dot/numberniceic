import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../widgets/shared_footer.dart';
import '../services/api_service.dart';

class NumberAnalysisPage extends StatefulWidget {
  const NumberAnalysisPage({super.key});

  @override
  State<NumberAnalysisPage> createState() => _NumberAnalysisPageState();
}

class _NumberAnalysisPageState extends State<NumberAnalysisPage> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  List<String> _mainPairs = [];
  List<String> _hiddenPairs = [];
  Map<String, dynamic>? _analysisData;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    if (value.length == 10) {
      _analyzeNumber(value);
    } else {
      if (_mainPairs.isNotEmpty) {
        setState(() {
          _mainPairs = [];
          _hiddenPairs = [];
          _analysisData = null;
        });
      }
    }
  }

  Future<void> _analyzeNumber(String number) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.analyzeRawNumber(number);
      
      List<String> extractPairs(List<dynamic> list) {
        return list.map((e) => e['pair'] as String).toList();
      }

      setState(() {
        _analysisData = data;
        _mainPairs = extractPairs(data['main_pairs'] ?? []);
        _hiddenPairs = extractPairs(data['hidden_pairs'] ?? []);
      });
    } catch (e) {
      print('Analysis Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPairBadge(String pair, bool isMain) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMain ? Colors.amber : Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isMain ? Colors.amberAccent : Colors.grey[600]!, width: 1.5),
        boxShadow: isMain
            ? [
                BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : [],
      ),
      child: Text(
        pair,
        style: GoogleFonts.kanit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isMain ? Colors.black87 : Colors.white),
      ),
    );
  }

  Widget _buildCategoryRow(String title, Color color, Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();
    
    int good = (data['good'] is int) ? data['good'] : 0;
    int bad = (data['bad'] is int) ? data['bad'] : 0;
    
    // Web Logic Match: Fixed 25% display weight if category has active numbers
    double goodPct = good > 0 ? 25.0 : 0.0;
    double badPct = bad > 0 ? 25.0 : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 14, 
                height: 14, 
                decoration: BoxDecoration(
                  color: color, 
                  borderRadius: BorderRadius.circular(4)
                )
              ),
              const SizedBox(width: 12),
              Text(
                title, 
                style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF333333))
              ),
              const Spacer(),
              if (good > 0) 
                 Text('${goodPct.toStringAsFixed(0)}%', style: GoogleFonts.kanit(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 20)),
              if (bad > 0) ...[
                 const SizedBox(width: 16),
                 Text('${badPct.toStringAsFixed(0)}%', style: GoogleFonts.kanit(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 20)),
              ]
              else if (good == 0 && bad == 0)
                  Text('-', style: GoogleFonts.kanit(color: Colors.grey, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFDB931)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'เสริมเบอร์ 100%', 
                    style: GoogleFonts.kanit(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [
                         const Shadow(offset: Offset(0,1), blurRadius: 2, color: Colors.black12)
                      ]
                    )
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _analysisData?['category_breakdown'] as Map<String, dynamic>?;
    
    // Calculate Total Percentage Locally (Sum of 25s)
    double calculatedTotal = 0;
    
    // Prepare data for Chart
    // 0: Health, 1: Work, 2: Finance, 3: Love
    List<bool> activeCategories = [false, false, false, false];
    
    if (breakdown != null) {
      if ((breakdown['สุขภาพ']?['good'] ?? 0) > 0) { calculatedTotal += 25; activeCategories[0] = true; }
      if ((breakdown['การงาน']?['good'] ?? 0) > 0) { calculatedTotal += 25; activeCategories[1] = true; }
      if ((breakdown['การเงิน']?['good'] ?? 0) > 0) { calculatedTotal += 25; activeCategories[2] = true; }
      if ((breakdown['ความรัก']?['good'] ?? 0) > 0) { calculatedTotal += 25; activeCategories[3] = true; }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
         title: Text('วิเคราะห์เบอร์', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
         backgroundColor: const Color(0xFF333333),
         elevation: 0,
         centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF333333),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                   Text(
                    'ตรวจสอบพลังตัวเลขเบอร์โทรศัพท์',
                    style: GoogleFonts.kanit(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      onChanged: _onPhoneChanged,
                      style: GoogleFonts.kanit(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '08XXXXXXXX',
                        hintStyle: GoogleFonts.kanit(color: Colors.grey[300]),
                        border: InputBorder.none,
                        counterText: "",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                             _phoneController.clear();
                             _onPhoneChanged('');
                          },
                        )
                      ),
                    ),
                  ),
                  
                  if (_isLoading)
                     const Padding(
                       padding: EdgeInsets.only(top: 32),
                       child: CircularProgressIndicator(color: Colors.white),
                     ),

                  if (!_isLoading && _mainPairs.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text('คู่เลขหลัก', style: GoogleFonts.kanit(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _mainPairs.map((p) => _buildPairBadge(p, true)).toList(),
                    ),
                    
                    const SizedBox(height: 20),
                    Text('คู่เลขแฝง', style: GoogleFonts.kanit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _hiddenPairs.map((p) => _buildPairBadge(p, false)).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
            
            if (_analysisData != null && breakdown != null) 
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                     // Solar System Chart (Custom Painter)
                     SizedBox(
                       height: 200,
                       width: 200,
                       child: CustomPaint(
                         painter: SolarSystemPainter(activeCategories: activeCategories),
                         child: Center(
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Text(
                                 '${calculatedTotal.toStringAsFixed(0)}%',
                                 style: GoogleFonts.kanit(
                                   fontSize: 28, 
                                   fontWeight: FontWeight.bold,
                                   color: const Color(0xFF333333)
                                 ),
                               ),
                               Text(
                                 'คะแนนรวม',
                                 style: GoogleFonts.kanit(
                                   fontSize: 12, 
                                   color: Colors.grey[600]
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),
                     ),
                     const SizedBox(height: 32),

                     _buildCategoryRow('สุขภาพ', const Color(0xFF80CBC4), breakdown['สุขภาพ']),
                     _buildCategoryRow('การงาน', const Color(0xFF90CAF9), breakdown['การงาน']),
                     _buildCategoryRow('การเงิน', const Color(0xFFFFCC80), breakdown['การเงิน']),
                     _buildCategoryRow('ความรัก', const Color(0xFFF48FB1), breakdown['ความรัก']),
                     
                     const SizedBox(height: 20),
                     // Total Score
                     Container(
                       width: double.infinity,
                       padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                       decoration: BoxDecoration(
                         gradient: const LinearGradient(
                           colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                           begin: Alignment.centerLeft,
                           end: Alignment.centerRight,
                         ),
                         borderRadius: BorderRadius.circular(16),
                         border: Border.all(color: const Color(0xFFFCD34D), width: 2),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.amber.withOpacity(0.1),
                             blurRadius: 10,
                             offset: const Offset(0, 4),
                           ),
                         ]
                       ),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           if (calculatedTotal > 0)
                              const Icon(Icons.star_rounded, color: Color(0xFFDAA520), size: 36)
                           else 
                              const Icon(Icons.cancel, color: Colors.red, size: 36),
                              
                           const SizedBox(width: 12),
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text('รวม % ดี', style: GoogleFonts.kanit(fontSize: 14, color: const Color(0xFF92400E), fontWeight: FontWeight.w600)),
                               Text('${calculatedTotal.toStringAsFixed(0)}%', style: GoogleFonts.kanit(fontSize: 32, color: const Color(0xFF92400E), fontWeight: FontWeight.bold, height: 1.0)),
                             ],
                           ),
                         ],
                       ),
                     ),
                  ],
                ),
              )
            else if (!_isLoading)
             Padding(
               padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
               child: Column(
                 children: [
                   Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
                   const SizedBox(height: 16),
                   Text(
                     'รู้อิทธิพลของตัวเลขในเบอร์โทรศัพท์\nเพื่อเสริมดวงชะตาและชีวิต',
                     textAlign: TextAlign.center,
                     style: GoogleFonts.kanit(fontSize: 16, color: Colors.grey[500]),
                   ),
                 ],
               ),
             ),

            const SizedBox(height: 60),
            const SharedFooter(),
          ],
        ),
      ),
    );
  }
}

class SolarSystemPainter extends CustomPainter {
  final List<bool> activeCategories; // [Health, Work, Finance, Love]

  SolarSystemPainter({required this.activeCategories});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 30.0;
    
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Draw background circle
    canvas.drawCircle(center, radius - strokeWidth/2, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth/2);
    
    // Define colors to match Web App
    final colors = [
      const Color(0xFF80CBC4), // Health
      const Color(0xFF90CAF9), // Work
      const Color(0xFFFFCC80), // Finance
      const Color(0xFFF48FB1), // Love
    ];

    // Starting from top (-pi/2)
    double startAngle = -math.pi / 2;
    double sweepAngle = math.pi / 2; // 90 degrees per category

    for (int i = 0; i < 4; i++) {
      if (activeCategories[i]) {
        final paint = Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
        
        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      }
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
