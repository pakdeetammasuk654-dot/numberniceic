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
import '../widgets/analyzer/top_10_section.dart';
import '../widgets/shared_footer.dart';
import '../widgets/adaptive_footer_scroll_view.dart';
import '../widgets/solar_system_analysis_card.dart';
import '../widgets/auto_scrolling_avatar_list.dart';
import '../widgets/buddhist_day_badge.dart';
import '../widgets/shimmering_gold_wrapper.dart';
import '../widgets/solar_system_widget.dart';
import '../widgets/analyzer/actions_section.dart';
import '../widgets/category_nested_donut.dart';

import 'login_page.dart';
import 'numerology_detail_page.dart';
import 'linguistic_detail_page.dart';
import 'shop_page.dart';
import 'number_analysis_page.dart';
import 'shipping_address_page.dart';
import 'notification_list_page.dart';
import 'main_tab_page.dart';
import '../widgets/pattern_background.dart';
import '../widgets/daily_miracle_card.dart';

class AnalyzerPage extends StatefulWidget {
  final String? initialName;
  final String? initialDay;
  final AnalyzerViewModel? viewModel;
  final VoidCallback? onNavigateToNaming;

  const AnalyzerPage({super.key, this.initialName, this.initialDay, this.viewModel, this.onNavigateToNaming});

  @override
  State<AnalyzerPage> createState() => _AnalyzerPageState();
}

class _AnalyzerPageState extends State<AnalyzerPage> with TickerProviderStateMixin {
  late AnalyzerViewModel _viewModel;
  bool _isOwnViewModel = false;
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
    
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
      _isOwnViewModel = false;
    } else {
      _viewModel = AnalyzerViewModel();
      _isOwnViewModel = true; 
    }

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

    _checkNotification();
  }
  
  void _onViewModelUpdate() {
     if (mounted) setState(() {});
     if (_nameController.text != _viewModel.currentName) {
       _nameController.text = _viewModel.currentName;
       // Only move cursor to end if focused, otherwise just updating text is enough
       if (_nameController.selection.baseOffset == -1) {
          _nameController.selection = TextSelection.fromPosition(TextPosition(offset: _nameController.text.length));
       }
     }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    if (_isOwnViewModel) _viewModel.dispose();
    _nameController.dispose();
    _scrollController.dispose();
    _rotationController.dispose();
    _rotationControllerOuter.dispose();
    super.dispose();
  }

  // --- Notification Logic ---
  bool _hasUnreadNotification = false;
  int _unreadCount = 0;

  Future<void> _checkNotification() async {
    final token = await AuthService.getToken();
    final isLoggedIn = token != null;
    
    if (isLoggedIn) {
        try {
            final count = await ApiService.getUnreadNotificationCount();
            if (mounted) {
                setState(() {
                    _unreadCount = count;
                    _hasUnreadNotification = count > 0;
                });
            }
        } catch (_) {}
    }
  }

  void _handleNotificationTap() {
    AuthService.isLoggedIn().then((isLoggedIn) {
      if (isLoggedIn) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationListPage()),
        ).then((_) {
             _checkNotification();
             // Reset UI in case user deleted notifications
        });
      } else {
        CustomToast.show(context, 'ไม่มีการแจ้งเตือนใหม่');
      }
    });
  }

  // --- Handlers ---
  
  void _handleNameChange(String val) {
    _viewModel.setName(val);
    if (!_viewModel.isAvatarScrolling && val.isNotEmpty) {
      _viewModel.setAvatarScrolling(true);
    }
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

  
    @override
  Widget build(BuildContext context) {
    final result = _viewModel.analysisResult;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: DefaultTabController(
        length: 2,
        child: PatternBackground(
          isDark: Theme.of(context).brightness == Brightness.dark,
          child: Column(
            children: [
              // Sticky Tab Bar
              Container(
                 color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF16213E) : Colors.white,
                 child: Column(
                   children: [
                      TabBar(
                        labelColor: const Color(0xFFFFD700), // Gold works for both
                        unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF64748B),
                        indicatorColor: const Color(0xFFFFD700),
                        indicatorWeight: 3,
                        labelStyle: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.normal),
                        tabs: const [
                          Tab(text: "ผลการวิเคราะห์"),
                          Tab(text: "เครื่องมือ"),
                        ],
                      ),
                      Container(height: 1, color: Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.grey[300]),
                   ],
                 ),
              ),
              
              if (_viewModel.isSolarLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 20),
                    child: Center(
                      child: Column(
                         children: [
                           const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700))),
                           const SizedBox(height: 10),
                           Text('กำลังวิเคราะห์...', style: GoogleFonts.kanit(color: Colors.white70)),
                         ],
                       ),
                    ),
                  ),

              Expanded(
                child: TabBarView(
                  children: [
                    _buildAnalysisTab(result),
                    _buildToolsTab(),
                  ],
                ),
              ),
            ],
          ),

        ),
      ),
      floatingActionButton: _showScrollToTop ? FloatingActionButton(
        onPressed: () {
          if (_scrollController.hasClients) {
             _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
          }
        },
        backgroundColor: const Color(0xFF16213E),
        mini: true,
        elevation: 4,
        child: const Icon(Icons.arrow_upward, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildAnalysisTab(AnalysisResult? result) {
    // 1. Loading State
    if (_viewModel.isSolarLoading) {
       return CustomScrollView(
         physics: const BouncingScrollPhysics(),
         slivers: [
           if (context.findAncestorWidgetOfExactType<NestedScrollView>() != null)
             SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
           SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 20), child: _buildSolarSystemSkeleton())),
         ],
       );
    }

    // 2. Empty State
    if (result == null) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (context.findAncestorWidgetOfExactType<NestedScrollView>() != null)
            SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  'วิเคราะห์ชื่อตามตำรา เลขศาสตร์ พลังเงา',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kanit(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF1E293B), 
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 8),
                const DailyMiracleCard(),
                const SizedBox(height: 40),
                // Icon(Icons.touch_app_rounded, size: 48, color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[300]),
              ],
            ),
          ),
        ],
      );
    }

    // 3. Result State
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      // padding: const EdgeInsets.only(top: 20, bottom: 100), // Slivers don't take padding broadly like this usually, use SliverPadding
      slivers: [
        if (context.findAncestorWidgetOfExactType<NestedScrollView>() != null)
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
        SliverPadding(
          padding: const EdgeInsets.only(top: 0, bottom: 20),
          sliver: SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Column(
              children: [
                 Top10Section(
                   data: result.bestNames,
                   showTop10: _viewModel.showTop10,
                   showGoodOnly: _viewModel.isAuspicious,
                   isVip: MainTabPage.of(context)?.isVip ?? result.isVip,
                   isLoading: _viewModel.isNamesLoading,
                   isSwitching: _viewModel.isTop10Switching,
                   onToggleTop10: _viewModel.toggleShowTop10,
                   onNameSelected: (name) {
                      _viewModel.setName(name);
                      _nameController.text = name;
                      _viewModel.analyze();
                      _viewModel.triggerScrollToTop();
                      widget.onNavigateToNaming?.call();
                   },
                 ),
                 const SizedBox(height: 20),
              ],
            ),
           ),
          ),
        ),
        const SliverFillRemaining(
           hasScrollBody: false,
           child: Align(
             alignment: Alignment.bottomCenter,
             child: SharedFooter(),
           ),
        ),
      ],
    );
  }

  Widget _buildToolsTab() {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        if (context.findAncestorWidgetOfExactType<NestedScrollView>() != null) 
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                   margin: const EdgeInsets.only(bottom: 20),
                   child: Text('เครื่องมือเพิ่มเติม', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                ),
                _buildThreeActionButtons(),
              ],
            ),
          ),
        ),
        const SliverFillRemaining(
           hasScrollBody: false,
           child: Align(
             alignment: Alignment.bottomCenter,
             child: SharedFooter(),
           ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Text(
            'กำลังวิเคราะห์ชื่อ +3 แสนรายชื่อ...',
            style: GoogleFonts.kanit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(height: 200, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(24))),
        ],
      ),
    );
  }

  Widget _buildThreeActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
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
              label: 'บันทึกชื่อ',
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center, maxLines: 1),
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 1; // +1 to avoid pixel gaps
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white.withOpacity(0.95), // Slight transparency for glass effect?
      child: Column(
        children: [
             _tabBar,
             Container(height: 1, color: Colors.grey[200]),
        ],
      )
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
