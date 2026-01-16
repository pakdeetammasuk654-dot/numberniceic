import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/analyzer_view_model.dart';
import '../widgets/analyzer/actions_section.dart';
import '../widgets/analyzer/analysis_toggles.dart';
import '../widgets/auto_scrolling_avatar_list.dart';
import '../models/sample_name.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'shop_page.dart';
import 'main_tab_page.dart';
import '../widgets/pattern_background.dart';

class UnlimitedAnalyzerPage extends StatefulWidget {
  final AnalyzerViewModel? viewModel;
  final VoidCallback? onNavigateToNaming;

  const UnlimitedAnalyzerPage({super.key, this.viewModel, this.onNavigateToNaming});

  @override
  State<UnlimitedAnalyzerPage> createState() => _UnlimitedAnalyzerPageState();
}

class _UnlimitedAnalyzerPageState extends State<UnlimitedAnalyzerPage> {
  late AnalyzerViewModel _viewModel;
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Future<List<SampleName>>? _sampleNamesFuture;
  bool _showBackToTop = false;
  Set<int> _badNumbers = {};

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? AnalyzerViewModel();
    _nameController.text = _viewModel.currentName;
    _viewModel.addListener(_onViewModelUpdate);
    _sampleNamesFuture = ApiService.getSampleNames();

    // Fetch Bad Numbers
    ApiService.getBadNumbers().then((nums) {
      if (nums.isNotEmpty && mounted) {
        setState(() {
          _badNumbers = nums;
        });
      }
    });

    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.offset > 300) {
      if (!_showBackToTop && mounted) {
        setState(() => _showBackToTop = true);
      }
    } else {
      if (_showBackToTop && mounted) {
        setState(() => _showBackToTop = false);
      }
    }
  }

  @override
  void dispose() {
    if (widget.viewModel == null) {
      _viewModel.dispose();
    } else {
      _viewModel.removeListener(_onViewModelUpdate);
    }
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndReloadForVip();
  }

  void _checkAndReloadForVip() {
    final mainTab = MainTabPage.of(context);
    final result = _viewModel.analysisResult;
    
    // If User is VIP (from MainTab), but Data is Old/Limited (result.isVip = false)
    // and we are not currently loading.
    if (mainTab != null && mainTab.isVip && 
        result != null && (!result.isVip || (result.similarNames?.length ?? 0) <= 3) && 
        !_viewModel.isLoading) {
          
      // SchedulerBinding to avoid build-phase setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
         debugPrint("🔄 Auto-refetching analysis for VIP...");
         _viewModel.analyze();
      });
    }
  }

  void _onViewModelUpdate() {
    if (mounted) {
      setState(() {
        if (_nameController.text != _viewModel.currentName) {
          _nameController.text = _viewModel.currentName;
        }
      });
      // Also check periodically on update (e.g. if viewmodel finished loading and still wrong?)
      // But didChangeDependencies is safer for context-based check
    }
  }
  void _handleShopNavigation() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (mounted) {
      if (!isLoggedIn) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ShopPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _viewModel.analysisResult;
    final mainTab = MainTabPage.of(context);

    // Show full loading screen only when data is actively being fetched.
    final bool showLoading = _viewModel.isLoading;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          PatternBackground(isDark: isDark),
          NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            if (scrollNotification is ScrollStartNotification) {
              FocusScope.of(context).unfocus();
            }
            return false;
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
              SliverToBoxAdapter(
                child: Column(
                  children: [
// Search Form Removed

                    
                    // Empty State
                    if (result == null && !showLoading)
                       Container(
                          height: 400,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                               const Icon(Icons.auto_awesome_rounded, size: 64, color: Color(0xFFCBD5E1)),
                               const SizedBox(height: 24),
                               Text('วิเคราะห์ชื่อตามตำรา', style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF334155))),
                               const SizedBox(height: 8),
                               Text('เลขศาสตร์ พลังเงา', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontSize: 16, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                            ],
                          ),
                       ),

                     if (showLoading)
                        Column(
                          children: [
                             Padding(
                               padding: const EdgeInsets.only(top: 20, bottom: 0),
                               child: RichText(
                                 text: TextSpan(
                                   style: GoogleFonts.kanit(fontSize: 16, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                   children: [
                                     const TextSpan(text: 'หาชื่อดีให้ '),
                                     TextSpan(text: '"${_viewModel.currentName}"', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                                     const TextSpan(text: ' เกิดวัน '),
                                     TextSpan(text: '"${_getDayLabel(_viewModel.selectedDay)}"', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                                   ],
                                 ),
                               ),
                             ),
                             AnalysisToggles(
                               showGoodOnly: _viewModel.isAuspicious, // Map isAuspicious for GoodOnly
                               enabled: false,
                               onToggleGoodOnly: null,
                             ),
                             Padding(padding: const EdgeInsets.only(top: 20), child: _buildSolarSystemSkeleton()),
                          ],
                        ),

                    if (result != null && !showLoading)
                       Column(
                         children: [
                            Builder(builder: (context) {
                              final totalBest = result.bestNames?.totalBest ?? 1000;
                              final similarNamesCount = result.similarNames?.length ?? 100;
                              
                              // If showing "ชื่อดี +3 แสน" (auspicious), calculate last ranks
                              // Otherwise, start from rank 1
                              final startRank = _viewModel.isAuspicious 
                                  ? (totalBest - similarNamesCount + 1)
                                  : 1;
                              
                              print('📊 [ActionsSection] totalBest=$totalBest, count=$similarNamesCount, isAuspicious=${_viewModel.isAuspicious}, startRank=$startRank');
                              
                               return ActionsSection(
                               currentName: _viewModel.currentName,
                               selectedDayLabel: _getDayLabel(_viewModel.selectedDay),
                               similarNames: result.similarNames,
                               startRank: startRank,
                               showGoodOnly: _viewModel.isAuspicious,
                               isVip: MainTabPage.of(context)?.isVip ?? result.isVip,
                               isLoading: _viewModel.isNamesLoading,
                               badNumbers: _badNumbers,
                               inputNameChars: result.solarSystem?.sunDisplayNameHtml, // Pass parsed chars
                               isInputNamePerfect: (result.solarSystem?.totalNegativeScore ?? 0) == 0 &&
                                                   !(result.solarSystem?.sunDisplayNameHtml.any((c) => c.isBad) ?? false), // Calc perfect
                               onToggleGoodOnly: _viewModel.toggleAuspicious,
                               onShopPressed: _handleShopNavigation,
                               onPageChanged: () {
                                  _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeOut);
                               },
                               onNameSelected: (name) {
                                  _viewModel.setName(name);
                                  _nameController.text = name;
                                  _viewModel.analyze();
                                  
                                  if (widget.onNavigateToNaming != null) {
                                      widget.onNavigateToNaming!();
                                  } else {
                                      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                                  }
                               },
                             );
                            }),
                              const SizedBox(height: 100),
                          ],
                        ),
                   ],
                 ),
               ),
             ],
           ),
         ),
        ],
      ),
      floatingActionButton: _showBackToTop ? Padding(
        padding: const EdgeInsets.only(bottom: 90, right: 0), // Raise significantly to clear bottom bar
        child: FloatingActionButton(
          onPressed: () {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutQuint,
            );
          },
          heroTag: 'back_to_top_analyzer',
          backgroundColor: const Color(0xFF7E22CE),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 32),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  

  Widget _buildSolarSystemSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 50, height: 50,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7E22CE)), // Purple (Tab Color)
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            _viewModel.loadingCount > 0 
                ? "พบชื่อคล้ายคุณ '${_viewModel.currentName}' แล้ว ${_viewModel.loadingCount} ชื่อ..."
                : (_viewModel.scannedCount > 0 
                     ? 'กำลังตรวจสอบ... ${_viewModel.scannedCount} รายชื่อ' 
                     : 'กำลังวิเคราะห์ชื่อ +3 แสนรายชื่อ...'),
            style: GoogleFonts.kanit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF7E22CE), // Purple Text
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'เพื่อค้นหาชื่อที่ดีที่สุดสำหรับคุณ',
            style: GoogleFonts.kanit(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Skeleton Box
          Container(
             height: 300, 
             width: double.infinity,
             decoration: BoxDecoration(
               color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
               borderRadius: BorderRadius.circular(24),
               border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
             ),
          ),
        ],
      ),
    );
  }

  String _getDayLabel(String value) {
    final option = _viewModel.days.firstWhere(
      (o) => o.value == value, 
      orElse: () => _viewModel.days[0]
    );
    return option.label.replaceFirst('วัน', '');
  }
}
