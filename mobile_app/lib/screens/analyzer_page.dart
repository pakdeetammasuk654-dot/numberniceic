import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sample_name.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/analysis_result.dart';
import '../models/solar_system_data.dart';
import '../viewmodels/analyzer_view_model.dart';
import '../widgets/analyzer/top_4_section.dart';
import '../widgets/shared_footer.dart';
import '../widgets/solar_system_analysis_card.dart';
import '../widgets/auto_scrolling_avatar_list.dart';
import '../widgets/shimmering_gold_wrapper.dart';
import '../widgets/solar_system_widget.dart';
import '../widgets/analyzer/actions_section.dart';
import '../widgets/category_nested_donut.dart';

import 'login_page.dart';
import 'numerology_detail_page.dart';
import 'linguistic_detail_page.dart';
import 'shop_page.dart';
import 'number_analysis_page.dart';
import 'main_tab_page.dart';

class AnalyzerPage extends StatefulWidget {
  final String? initialName;
  final String? initialDay;

  const AnalyzerPage({super.key, this.initialName, this.initialDay});

  @override
  State<AnalyzerPage> createState() => _AnalyzerPageState();
}

class _AnalyzerPageState extends State<AnalyzerPage> with TickerProviderStateMixin {
  late AnalyzerViewModel _viewModel;
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late Future<List<SampleName>> _sampleNamesFuture;
  late AnimationController _rotationController;
  late AnimationController _rotationControllerOuter;
  bool _showScrollToTop = false;
  bool _showGoodOnly = false; // Added state for filtering
  Set<int> _badNumbers = {}; // Default empty, wait for API

  @override
  void initState() {
    super.initState();
    
    _viewModel = AnalyzerViewModel();
    _viewModel.init(widget.initialName, widget.initialDay);
    _viewModel.addListener(_onViewModelUpdate); // Rebuild on changes
    
    _nameController.text = _viewModel.currentName;
    
    // Animations for Solar System
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _rotationControllerOuter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 31111), 
    )..repeat();
    
    _sampleNamesFuture = ApiService.getSampleNames();
    
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

    // Fetch Bad Numbers
    ApiService.getBadNumbers().then((nums) {
      if (nums.isNotEmpty && mounted) {
        setState(() {
          _badNumbers = nums;
        });
      }
    });
  }
  
  void _onViewModelUpdate() {
     if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    _rotationController.dispose();
    _rotationControllerOuter.dispose();
    super.dispose();
  }

  // --- Handlers ---
  
  void _handleNameChange(String val) {
    _viewModel.setName(val);
  }
  
  Future<void> _handleUnlockAction() async {
    if (!_viewModel.isLoggedIn) {
       Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      ).then((_) {
         _viewModel.init(null, null); // Refresh login status logic if needed
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ShopPage()),
      ).then((_) {
          // Maybe refresh state?
      });
    }
  }

  void _showNumerologyDetail() {
    final solar = _viewModel.analysisResult?.solarSystem;
    if (solar == null) return;
    
    final decodedParts = solar.decodedParts;
    final uniquePairs = solar.allUniquePairs;
    final name = solar.cleanedName;
    final isVip = _viewModel.analysisResult?.isVip ?? false;

    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NumerologyDetailPage(
          name: name,
          decodedParts: decodedParts,
          uniquePairs: uniquePairs,
          isVip: isVip,
          onUpgrade: _handleUnlockAction,
        ),
      ),
    );
  }
  
  Future<void> _showLinguisticAnalysis() async {
    String name = _nameController.text;
    if (_viewModel.analysisResult?.solarSystem != null) {
       name = _viewModel.analysisResult!.solarSystem!.cleanedName;
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
                    Text('โปรดรอสักครู่...', style: GoogleFonts.kanit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('กำลังค้นหารากศัพท์และวิเคราะห์ภาษา...', style: GoogleFonts.kanit(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () { isCancelled = true; Navigator.of(dialogContext).pop(); },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
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
      Navigator.of(context).pop();
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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  Future<void> _saveCurrentName() async {
    final solar = _viewModel.analysisResult?.solarSystem;
    if (solar == null) return;
    
    try {
      final msg = await ApiService.saveName(
        name: solar.cleanedName,
        day: solar.inputDayRaw,
        totalScore: solar.grandTotalScore.toInt(),
        satSum: solar.totalNumerologyValue.toInt(),
        shaSum: solar.totalShadowValue.toInt(),
      );
      if (mounted) {
        ApiService.dashboardRefreshSignal.value++;
        _showStyledDialog(
          title: 'สำเร็จ',
          message: '$msg\nคุณสามารถดูรายชื่อที่บันทึกไว้ได้ที่เมนู Dashboard',
          icon: Icons.check_circle_outline,
          color: Colors.green,
          secondaryActionLabel: 'ไปที่ Dashboard',
          onSecondaryAction: () {
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
        if (errorMsg.contains('เข้าสู่ระบบ')) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
        } else {
          _showStyledDialog(title: 'แจ้งเตือน', message: errorMsg, icon: Icons.info_outline, color: Colors.orange);
        }
      }
    }
  }

  void _showStyledDialog({required String title, required String message, required IconData icon, required Color color, String? secondaryActionLabel, VoidCallback? onSecondaryAction}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Text(title, style: GoogleFonts.kanit(fontWeight: FontWeight.bold))]),
        content: Text(message, style: GoogleFonts.kanit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('ตกลง', style: GoogleFonts.kanit(color: Colors.grey[600]))),
          if (secondaryActionLabel != null)
            ElevatedButton(
              onPressed: () { Navigator.pop(context); if (onSecondaryAction != null) onSecondaryAction(); },
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: Text(secondaryActionLabel, style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildSearchForm() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            onChanged: _handleNameChange,
            decoration: InputDecoration(
              labelText: 'กรอกชื่อที่ต้องการวิเคราะห์',
              labelStyle: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 14),
              hintText: 'กรอกชื่อของคุณ',
              hintStyle: GoogleFonts.kanit(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
              suffixIcon: IconButton(icon: const Icon(Icons.cancel, color: Colors.grey), onPressed: () { _nameController.clear(); _handleNameChange(''); }),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.grey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[400]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF667EEA), width: 1.5)),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            'วิเคราะห์อัตโนมัติเมื่อพิมพ์ชื่อ',
            style: GoogleFonts.kanit(fontSize: 12, color: const Color(0xFF667EEA)),
          ),
          const SizedBox(height: 20),
          
          // Dropdown for Day Selection
          DropdownButtonFormField<String>(
            value: _viewModel.selectedDay,
            decoration: InputDecoration(
              labelText: 'วันเกิด',
              labelStyle: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.grey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[400]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF667EEA), width: 1.5)),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              prefixIcon: const Icon(Icons.calendar_today_outlined, color: Colors.grey),
            ),
            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
            style: GoogleFonts.kanit(fontSize: 16, color: Colors.black87),
            items: _viewModel.days.map((day) {
              return DropdownMenuItem(
                value: day.value,
                child: Row(
                  children: [
                    Icon(day.icon, color: day.color, size: 22),
                    const SizedBox(width: 10),
                    Text(day.label, style: GoogleFonts.kanit(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) _viewModel.setDay(val);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _viewModel.analysisResult;
    final solar = result?.solarSystem;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('วิเคราะห์ชื่อ', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF333333),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.dialpad, color: Colors.white), onPressed: () { NumberAnalysisPage.show(context); }, tooltip: 'วิเคราะห์เบอร์'),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}, tooltip: 'การแจ้งเตือน'),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF667EEA).withOpacity(0.05), const Color(0xFF764BA2).withOpacity(0.03), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              // 0. Search & Sample
              _buildSearchForm(),
              _buildSampleNamesSection(),
              
              if (result == null && _viewModel.isLoading)
                  Padding(padding: const EdgeInsets.only(top: 40), child: _buildSolarSystemSkeleton()),

              if (result != null)
                 AnimatedSwitcher(
                   duration: const Duration(milliseconds: 800),
                   layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                     return Stack(
                       alignment: Alignment.topCenter,
                       clipBehavior: Clip.none,
                       children: <Widget>[
                         ...previousChildren,
                         if (currentChild != null) currentChild,
                       ],
                     );
                   },
                   child: Builder(
                     key: ValueKey(solar?.cleanedName),
                     builder: (context) {
                       if (solar == null) return const SizedBox.shrink();

                       // FLATTENED STACK: This ensures the planets are on top of EVERYTHING in this analysis block.
                       return Stack(
                         clipBehavior: Clip.none, // Ensure orbits are not clipped
                         children: [
                           // Layer 1: The Main Content Column (Everything scrollable together)
                           Column(
                             children: [
                               // 1. Text Info (Name & Pills)
                               Padding(
                                 padding: const EdgeInsets.only(top: 205), 
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
                                                     color: dc.isBad ? const Color(0xFFFF1744) : (isPerfect ? const Color(0xFF8B6F00) : Colors.black87), 
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
                                           _buildPill(Icons.calendar_today_outlined, _viewModel.days.firstWhere((d) => solar.inputDayRaw.contains(d.value), orElse: () => _viewModel.days[0]).label, const Color(0xFFF1F5F9), const Color(0xFF334155)),
                                           const SizedBox(width: 12),
                                           if (solar.klakiniChars.isNotEmpty)
                                             _buildPill(Icons.warning_amber_rounded, solar.klakiniChars.join(' '), const Color(0xFFFFEBEE), const Color(0xFFFF1744))
                                           else
                                             _buildPill(null, 'ไม่มีกาลกิณี', const Color(0xFFE8F5E9), const Color(0xFF00C853)),
                                         ],
                                       ),
                                       const SizedBox(height: 12),
                                       RichText(
                                         text: TextSpan(
                                           style: GoogleFonts.kanit(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                           children: [
                                             const TextSpan(text: 'พยัญชนะหรือสระ'),
                                             TextSpan(text: 'สีแดง', style: GoogleFonts.kanit(color: const Color(0xFFFF1744), fontWeight: FontWeight.bold)), // Highlighted red
                                             const TextSpan(text: 'คือกาลกิณี'),
                                           ],
                                         ),
                                       ),
                                       const SizedBox(height: 24),
                                       // Donut Chart Removed as per design request
                                       Padding(
                                         padding: const EdgeInsets.only(bottom: 16),
                                         child: SolarSystemAnalysisCard(data: solar.toJson(), cleanedName: solar.cleanedName),
                                       ),
                                       _buildThreeActionButtons(),
                                       const SizedBox(height: 24),
                                       CategoryNestedDonut(
                                         categoryBreakdown: solar.categoryBreakdown,
                                         totalPairs: solar.totalPairs,
                                         grandTotalScore: solar.grandTotalScore.toInt(),
                                         totalPositiveScore: solar.totalPositiveScore,
                                         totalNegativeScore: solar.totalNegativeScore,
                                         analyzedName: solar.cleanedName,
                                       ),
                                    ],
                                 ),
                               ),

                               // 2. Extra Sections (Top 4, Actions)
                               // _buildActionsGrid(), // Removed in favor of 3-button row above
                               const SizedBox(height: 40),
                               // 2. Extra Sections (Top 4, Actions) - Restored
                               Top4Section(
                                 data: result.bestNames,
                                 showTop4: _viewModel.showTop4,
                                 showKlakini: _viewModel.showKlakiniTop4,
                                 isLoading: _viewModel.isNamesLoading,
                                 isSwitching: _viewModel.isTop4Switching,
                                 onToggleTop4: _viewModel.toggleShowTop4,
                                 onToggleKlakini: _viewModel.toggleShowKlakiniTop4,
                                 onNameSelected: (name) {
                                    _viewModel.setName(name);
                                    _nameController.text = name;
                                    _viewModel.analyze();
                                    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                                 },
                               ),
                               const SizedBox(height: 24),
                               ActionsSection(
                                 similarNames: result.similarNames,
                                 showKlakini: _viewModel.showKlakini,
                                 showGoodOnly: _viewModel.isAuspicious, 
                                 isVip: result.isVip,
                                 isLoading: _viewModel.isNamesLoading, // Added
                                 badNumbers: _badNumbers,
                                 onToggleKlakini: _viewModel.toggleShowKlakini,
                                 onToggleGoodOnly: _viewModel.toggleAuspicious,
                                 onNameSelected: (name) {
                                    _viewModel.setName(name);
                                    _nameController.text = name;
                                    _viewModel.analyze(); 
                                    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                                 },
                               ),

                               const SharedFooter(),
                               const SizedBox(height: 40),
                             ],
                           ),

                           // Layer 2: Score Summary (Positioned over Layer 1)
                           Positioned(
                             left: 16,
                             top: 75, 
                             width: 190,
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Text('คะแนนรวม', style: GoogleFonts.kanit(fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
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
                                           color: solar.grandTotalScore >= 0 ? const Color(0xFF00C853) : const Color(0xFFFF1744),
                                           height: 1.0
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(height: 0), 
                                 Row(
                                   children: [
                                     _buildSmallPill('ดี +${solar.totalPositiveScore}', const Color(0xFFE8F5E9), const Color(0xFF00C853)),
                                     const SizedBox(width: 8),
                                     _buildSmallPill('ร้าย ${solar.totalNegativeScore}', const Color(0xFFFFEBEE), const Color(0xFFFF1744)),
                                   ],
                                 ),
                               ],
                             ),
                           ),

                           // Layer 3: Solar System (ABSOLUTELY ON TOP)
                           Positioned(
                             right: -50, 
                             top: -15, 
                             left: 80, 
                             height: 280, // Increased height to prevent planet clipping
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
            ],
          ),
        ),
      ),
      floatingActionButton: _showScrollToTop ? FloatingActionButton(
        onPressed: () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
        backgroundColor: Colors.white,
        mini: true,
        elevation: 4,
        child: const Icon(Icons.arrow_upward, color: Colors.black87),
      ) : null,
    );
  }

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
          const SizedBox(height: 180),
          Container(width: 120, height: 40, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 20),
          Container(height: 400, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(24))),
        ],
      ),
    );
  }
  
  Widget _buildSampleNamesSection() {
    return FutureBuilder<List<SampleName>>(
      future: _sampleNamesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: EdgeInsets.zero, // Removed bottom margin to be even closer
          child: SizedBox(
            height: 90,
            child: AutoScrollingAvatarList(
              samples: snapshot.data!,
              currentName: _nameController.text,
              onSelect: (name) {
                _viewModel.setName(name);
                _nameController.text = name;
              },
            ),
          ),
        );
      },
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
              bgColor: const Color(0xFFEEF2FF), // Indigo 50
              borderColor: const Color(0xFFA5B4FC), // Indigo 300
              shadowColor: const Color(0xFF6366F1), // Indigo 500 for 3D edge
              textColor: const Color(0xFF4338CA), // Indigo 700
              onPressed: _showNumerologyDetail,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPillButton(
              icon: Icons.menu_book_rounded,
              label: 'ภาษาศาสตร์',
              bgColor: const Color(0xFFECFDF5), // Emerald 50
              borderColor: const Color(0xFF6EE7B7), // Emerald 300
              shadowColor: const Color(0xFF10B981), // Emerald 500 for 3D edge
              textColor: const Color(0xFF047857), // Emerald 700
              onPressed: _showLinguisticAnalysis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPillButton(
              icon: Icons.save_outlined, // Changed to match floppy disk reference
              label: 'บันทึก',
              bgColor: const Color(0xFFF8FAFC), // Slate 50
              borderColor: const Color(0xFFCBD5E1), // Slate 300
              shadowColor: const Color(0xFF94A3B8), // Slate 400 for 3D edge
              textColor: const Color(0xFF334155), // Slate 700
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
        padding: const EdgeInsets.symmetric(vertical: 8), // Reduced size
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2.0), // Thicker border
          boxShadow: [
             BoxShadow(
               color: shadowColor ?? borderColor,
               offset: const Offset(0, 5), // Deep 3D Shadow
               blurRadius: 0,
             ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.kanit(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  bool get resultIsVip => _viewModel.analysisResult?.isVip ?? false;

  Widget _buildActionButton({
    required IconData icon, 
    required String label, 
    required Color color, 
    Color textColor = Colors.white, 
    required VoidCallback onPressed, 
    bool isOutlined = false
  }) {
    final hsl = HSLColor.fromColor(color);
    final lightColor = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    final shadowColor = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isOutlined ? Colors.white : null,
          gradient: isOutlined ? null : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lightColor, color],
          ),
          border: isOutlined ? Border.all(color: color.withOpacity(0.3), width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: isOutlined ? Colors.black.withOpacity(0.05) : shadowColor,
              offset: const Offset(0, 4),
              blurRadius: isOutlined ? 0 : 0, // Solid 3D edge
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isOutlined ? color : textColor),
            const SizedBox(width: 10),
            Text(
              label, 
              style: GoogleFonts.kanit(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: isOutlined ? color : textColor
              )
            ),
          ],
        ),
      ),
    );
  }
}
