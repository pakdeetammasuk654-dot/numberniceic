import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/analyzer_view_model.dart';
import '../widgets/analyzer/actions_section.dart';
import '../widgets/auto_scrolling_avatar_list.dart';
import '../models/sample_name.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'shop_page.dart';
import 'main_tab_page.dart';

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

    // Check if we are waiting for VIP data (Limited data shown to VIP user)
    bool isPendingVipUpdate = false;
    if (mainTab != null && mainTab.isVip && result != null) {
       if ((result.similarNames?.length ?? 0) <= 3) {
          isPendingVipUpdate = true;
       }
    }
    
    // Show full loading screen if loading ANY data (Solar/Names) or waiting for VIP update
    final bool showLoading = _viewModel.isLoading || isPendingVipUpdate;

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
        child: NotificationListener<ScrollNotification>(
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
                               const Icon(Icons.auto_awesome_rounded, size: 64, color: Colors.white24),
                               const SizedBox(height: 24),
                               Text('วิเคราะห์ชื่อตามตำรา', style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)),
                               const SizedBox(height: 8),
                               Text('เลขศาสตร์ พลังเงา', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontSize: 16, color: Colors.white38)),
                            ],
                          ),
                       ),

                    if (showLoading)
                        Padding(padding: const EdgeInsets.only(top: 40), child: _buildSolarSystemSkeleton()),

                    if (result != null && !showLoading)
                       Column(
                         children: [
                            ActionsSection(
                               similarNames: result.similarNames,
                               showKlakini: _viewModel.showKlakini,
                               showGoodOnly: _viewModel.isAuspicious,
                               isVip: MainTabPage.of(context)?.isVip ?? result.isVip,
                               isLoading: _viewModel.isNamesLoading,
                               badNumbers: _badNumbers,
                               onToggleKlakini: _viewModel.toggleShowKlakini,
                               onToggleGoodOnly: _viewModel.toggleAuspicious,
                               onShopPressed: _handleShopNavigation,
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
                             ),
                             const SizedBox(height: 100),
                         ],
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

  

  Widget _buildSolarSystemSkeleton() {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 50, height: 50,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'กำลังวิเคราะห์ชื่อ +3 แสนรายชื่อ...',
            style: GoogleFonts.kanit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'เพื่อค้นหาชื่อที่ดีที่สุดสำหรับคุณ',
            style: GoogleFonts.kanit(
              fontSize: 14,
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Skeleton Box
          Container(
             height: 300, 
             width: double.infinity,
             decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.05),
               borderRadius: BorderRadius.circular(24),
               border: Border.all(color: Colors.white10),
             ),
          ),
        ],
      ),
    );
  }
}
