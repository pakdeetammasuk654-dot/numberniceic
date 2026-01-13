import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sample_name.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/custom_toast.dart';
import '../models/analysis_result.dart';
import '../models/solar_system_data.dart';
import '../viewmodels/analyzer_view_model.dart';
import '../widgets/adaptive_footer_scroll_view.dart';
import '../widgets/solar_system_analysis_card.dart';
import '../widgets/auto_scrolling_avatar_list.dart';
import '../widgets/shimmering_gold_wrapper.dart';
import '../widgets/shared_footer.dart'; // Added import

import 'login_page.dart';
import 'numerology_detail_page.dart';
import 'linguistic_detail_page.dart';
import 'shop_page.dart';
import '../widgets/solar_system_widget.dart';
class NamingPage extends StatefulWidget {
  final String? initialName;
  final String? initialDay;
  final AnalyzerViewModel? viewModel;

  const NamingPage({super.key, this.initialName, this.initialDay, this.viewModel});

  @override
  State<NamingPage> createState() => _NamingPageState();
}

class _NamingPageState extends State<NamingPage> with TickerProviderStateMixin {
  late AnalyzerViewModel _viewModel;
  bool _isOwnViewModel = false;
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late Future<List<SampleName>> _sampleNamesFuture;
  late AnimationController _rotationController;
  late AnimationController _rotationControllerOuter;
  Set<int> _badNumbers = {};

  @override
  void initState() {
    super.initState();
    
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
      _isOwnViewModel = false;
    } else {
      _viewModel = AnalyzerViewModel();
      _isOwnViewModel = true;
    }

    _viewModel.init(widget.initialName, widget.initialDay);
    _viewModel.addListener(_onViewModelUpdate);
    
    _nameController.text = _viewModel.currentName;
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _rotationControllerOuter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 31111), 
    )..repeat();
    
    _sampleNamesFuture = ApiService.getSampleNames();

    ApiService.getBadNumbers().then((nums) {
      if (nums.isNotEmpty && mounted) {
        setState(() {
          _badNumbers = nums;
        });
      }
    });

    // Listen for scroll-to-top events
    _viewModel.scrollToTopNotifier.addListener(_scrollToTop);
  }
  
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }
  
  void _onViewModelUpdate() {
     if (mounted) setState(() {});
     if (_nameController.text != _viewModel.currentName) {
       _nameController.text = _viewModel.currentName;
       _nameController.selection = TextSelection.fromPosition(TextPosition(offset: _nameController.text.length));
     }
  }

  @override
  void dispose() {
    _viewModel.scrollToTopNotifier.removeListener(_scrollToTop);
    _viewModel.removeListener(_onViewModelUpdate);
    if (_isOwnViewModel) _viewModel.dispose();
    _nameController.dispose();
    _rotationController.dispose();
    _rotationControllerOuter.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleNameChange(String val) {
    _viewModel.setName(val);
    if (!_viewModel.isAvatarScrolling && val.isNotEmpty) {
      _viewModel.setAvatarScrolling(true);
    }
  }

  void _showNumerologyDetail() {
    if (_viewModel.analysisResult?.solarSystem == null) return;
    final solar = _viewModel.analysisResult!.solarSystem!;
    Navigator.push(context, MaterialPageRoute(builder: (context) => NumerologyDetailPage(
        name: solar.cleanedName,
        decodedParts: solar.decodedParts,
        uniquePairs: solar.allUniquePairs,
        isVip: _viewModel.analysisResult!.isVip,
        onUpgrade: () {
            Navigator.pop(context); 
            // ShopPage might not have a const constructor if it has non-final fields or is invalidly defined, removing const safely.
            Navigator.push(context, MaterialPageRoute(builder: (context) => ShopPage()));
        },
    )));
  }

  Future<void> _showLinguisticAnalysis() async {
    if (_viewModel.analysisResult?.solarSystem == null) return;
    final solar = _viewModel.analysisResult!.solarSystem!;

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await ApiService.analyzeLinguistically(solar.cleanedName);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      // Try multiple keys that might contain the result
      final String? analysisText = result['analysis'] ?? result['result'] ?? result['content'] ?? result['data'];

      if (analysisText != null) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => LinguisticDetailPage(
          name: solar.cleanedName,
          analysisHtml: analysisText, 
        )));
      } else {
        CustomToast.show(context, 'ไม่พบข้อมูลการวิเคราะห์ (No analysis key)', isSuccess: false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if open
        CustomToast.show(context, 'เกิดข้อผิดพลาด: ${e.toString()}', isSuccess: false);
      }
    }
  }

  Future<void> _saveCurrentName() async {
     final isLoggedIn = await AuthService.isLoggedIn();
     if (!isLoggedIn) {
       if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
       return;
     }

     if (_viewModel.analysisResult?.solarSystem == null) return;

     try {
       final solar = _viewModel.analysisResult!.solarSystem!;
       await ApiService.saveName(
          name: _viewModel.currentName, 
          day: _viewModel.selectedDay,
          totalScore: solar.grandTotalScore.toInt(),
          satSum: solar.totalNumerologyValue.toInt(),
          shaSum: solar.totalShadowValue.toInt(),
       );
       if (mounted) CustomToast.show(context, 'บันทึกชื่อเรียบร้อยแล้ว');
     } catch (e) {
       if (mounted) CustomToast.show(context, 'บันทึกไม่สำเร็จ: $e', isSuccess: false);
     }
  }

  // --- Widgets ---

  

    Widget _buildPill(IconData? icon, String text, Color bg, Color textC) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: textC), const SizedBox(width: 8)],
            Text(text, style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: textC)),
          ],
        ),
      );
  }

  Widget _buildSmallPill(String text, Color bg, Color textC) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: textC)),
      );
  }
  
  Widget _buildSolarSystemSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 80),
          // Loading message
          Text(
            'กำลังวิเคราะห์จาก +3 แสนรายชื่อ...',
            style: GoogleFonts.kanit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Loading indicator
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
          const SizedBox(height: 60),
          Container(width: 120, height: 40, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 20),
          Container(height: 400, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(24))),
        ],
      ),
    );
  }

  Widget _buildThreeActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildPillButton(
              icon: Icons.assignment_outlined,
              label: 'เลขศาสตร์',
              bgColor: const Color(0xFFEEF2FF),
              borderColor: const Color(0xFFA5B4FC),
              shadowColor: const Color(0xFF6366F1),
              textColor: const Color(0xFF4338CA),
              onPressed: _showNumerologyDetail,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPillButton(
              icon: Icons.menu_book_rounded,
              label: 'ภาษาศาสตร์',
              bgColor: const Color(0xFFECFDF5),
              borderColor: const Color(0xFF6EE7B7),
              shadowColor: const Color(0xFF10B981),
              textColor: const Color(0xFF047857),
              onPressed: _showLinguisticAnalysis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPillButton(
              icon: Icons.save_outlined,
              label: 'บันทึกชื่อ',
              bgColor: const Color(0xFFFEF3C7),
              borderColor: const Color(0xFFFBBF24),
              shadowColor: const Color(0xFFD97706),
              textColor: const Color(0xFF92400E),
              onPressed: _saveCurrentName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onPressed,
    Color? shadowColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: shadowColor ?? borderColor.withOpacity(0.5),
              blurRadius: 0,
              offset: const Offset(0, 3), // 3D Effect
            )
          ]
        ),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.kanit(color: textColor, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _viewModel.analysisResult;
    final solar = result?.solarSystem;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF1A1A2E),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          controller: _scrollController,
          slivers: [
            SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
            
            // 0. Loading State
            if (_viewModel.isSolarLoading)
               SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 40), child: _buildSolarSystemSkeleton())),

            // 1. Content State
            // Empty State
            if (result == null && !_viewModel.isSolarLoading)
               SliverToBoxAdapter(
                 child: Container(
                    height: 400,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.white24),
                         const SizedBox(height: 24),
                         Text('วิเคราะห์ชื่อตามตำรา', style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)),
                         const SizedBox(height: 8),
                         Text('เลขศาสตร์ พลังเงา', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontSize: 16, color: Colors.white38)),
                      ],
                    ),
                 ),
               ),

            if (result != null && !_viewModel.isSolarLoading)
               SliverToBoxAdapter(
                 child: AnimatedSwitcher(
                   duration: const Duration(milliseconds: 800),
                   child: Builder(
                     key: ValueKey(solar?.cleanedName),
                     builder: (context) {
                       if (solar == null) return const SizedBox.shrink();

                       return Stack(
                         clipBehavior: Clip.none,
                         children: [
                           // Main Content Column
                           Column(
                             children: [
                               // 1. Text Info (Name & Pills)
                               Padding(
                                 padding: const EdgeInsets.only(top: 290), // Increased from 205 to 290 to clear simpler header
                                 child: Column(
                                    children: [
                                       Builder(
                                         builder: (context) {
                                           final bool isPerfect = (solar.numNegativeScore == 0 && solar.shaNegativeScore == 0 && solar.klakiniChars.isEmpty);
                                           return ShimmeringGoldWrapper(
                                             enabled: isPerfect,
                                             child: Wrap(
                                               alignment: WrapAlignment.center,
                                               children: solar.sunDisplayNameHtml.map((dc) => Text(
                                                   dc.char,
                                                   style: GoogleFonts.kanit(
                                                     fontSize: 48, 
                                                     fontWeight: FontWeight.bold, 
                                                     color: dc.isBad ? const Color(0xFFFF6B6B) : (isPerfect ? const Color(0xFFFFD700) : Colors.white), 
                                                     height: 1.0
                                                   ),
                                               )).toList(),
                                             ),
                                           );
                                         },
                                       ),
                                       const SizedBox(height: 8),
                                       Row(
                                         mainAxisAlignment: MainAxisAlignment.center,
                                         children: [
                                           _buildPill(Icons.calendar_today_outlined, _viewModel.days.firstWhere((d) => solar.inputDayRaw.contains(d.value), orElse: () => _viewModel.days[0]).label, const Color(0x1AFFFFFF), const Color(0xFFFFFFFF)),
                                           const SizedBox(width: 12),
                                           if (solar.klakiniChars.isNotEmpty)
                                             _buildPill(Icons.warning_amber_rounded, solar.klakiniChars.join(' '), const Color(0x33FF6B6B), const Color(0xFFFF6B6B))
                                           else
                                             _buildPill(null, 'ไม่มีกาลกิณี', const Color(0x3334D399), const Color(0xFF34D399)),
                                         ],
                                       ),
                                       const SizedBox(height: 12),
                                       RichText(
                                         text: TextSpan(
                                           style: GoogleFonts.kanit(fontSize: 14, color: const Color(0x99FFFFFF), fontWeight: FontWeight.w500),
                                           children: [
                                             const TextSpan(text: 'พยัญชนะหรือสระ'),
                                             TextSpan(text: 'สีแดง', style: GoogleFonts.kanit(color: const Color(0xFFFF6B6B), fontWeight: FontWeight.bold)), 
                                             const TextSpan(text: 'คือกาลกิณี'),
                                           ],
                                         ),
                                       ),
                                       const SizedBox(height: 24),
                                       
                                       // Solar System Analysis Card
                                       Padding(
                                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                         child: SolarSystemAnalysisCard(data: solar.toJson(), cleanedName: solar.cleanedName),
                                       ),
                                       
                                       const SizedBox(height: 16),
                                       _buildThreeActionButtons(),
                                       const SizedBox(height: 40),
                                    ],
                                 ),
                               ),
                             ],
                           ),

                           // Layer 2: Score Summary
                           Positioned(
                             left: 16,
                             top: 75 + 10, // Adjusted +10
                             width: 190,
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Text('คะแนนรวม', style: GoogleFonts.kanit(fontSize: 14, color: const Color(0x99FFFFFF), fontWeight: FontWeight.bold)),
                                 const SizedBox(height: 0), 
                                 FittedBox(
                                   fit: BoxFit.scaleDown,
                                   alignment: Alignment.centerLeft,
                                   child: Row(
                                     children: [
                                       Text(solar.grandTotalScore >= 0 ? '😊' : '😭', style: const TextStyle(fontSize: 36)),
                                       const SizedBox(width: 10),
                                       Text(
                                         '${solar.grandTotalScore >= 0 ? '+' : ''}${solar.grandTotalScore.toInt()}',
                                         softWrap: false,
                                         maxLines: 1,
                                         style: GoogleFonts.kanit(
                                           fontSize: 36, 
                                           fontWeight: FontWeight.w900, 
                                           color: solar.grandTotalScore >= 0 ? const Color(0xFF34D399) : const Color(0xFFFF6B6B),
                                           height: 1.0
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(height: 0), 
                                 Row(
                                   children: [
                                     _buildSmallPill('ดี +${solar.totalPositiveScore}', const Color(0x3334D399), const Color(0xFF34D399)),
                                     const SizedBox(width: 8),
                                     _buildSmallPill('ร้าย ${solar.totalNegativeScore}', const Color(0x33FF6B6B), const Color(0xFFFF6B6B)),
                                   ],
                                 ),
                               ],
                             ),
                           ),

                           // Layer 3: Solar System (ABSOLUTELY ON TOP)
                           Positioned(
                             right: -35,
                             top: 10, // Changed from -65 to 10 to move it down below header line? No, just natural spacing.
                             height: 350, 
                             width: 350,
                             child: SolarSystemWidget(
                                 sumPair: solar.sumPair,
                                 mainPairs: solar.mainPairs,
                                 hiddenPairs: solar.hiddenPairs,
                                 title: solar.cleanedName,
                                 displayName: solar.sunDisplayNameHtml,
                                 isDead: solar.grandTotalScore < 0,
                             ),
                           ),
                         ],
                       );
                     },
                   ),
                 ),
               ),
              
              // Footer
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SharedFooter(),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
