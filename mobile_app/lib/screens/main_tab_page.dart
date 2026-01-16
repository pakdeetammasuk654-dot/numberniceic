import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/welcome_dialog.dart';
import 'landing_page.dart';
import 'analyzer_page.dart';
import 'unlimited_analyzer_page.dart';
import 'number_analysis_page.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'shop_page.dart';
import 'notification_list_page.dart';
import 'article_detail_page.dart';
import '../widgets/wallet_color_bottom_sheet.dart'; 
import '../services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'naming_page.dart';
import '../viewmodels/analyzer_view_model.dart';
import '../widgets/analyzer/shared_search_form.dart';
import '../widgets/analyzer/shared_sample_names.dart';
import '../models/sample_name.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/notification_bell.dart';
import '../widgets/buddhist_day_badge.dart';
import '../widgets/background_pattern_painter.dart';

class MainTabPage extends StatefulWidget {
  final int initialIndex;
  final bool forceLogout;
  final String? initialName;
  final String? initialDay;

  const MainTabPage({
    super.key, 
    this.initialIndex = 0, 
    this.forceLogout = false,
    this.initialName,
    this.initialDay,
  });

  @override
  State<MainTabPage> createState() => MainTabPageState();

  static MainTabPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainTabPageState>();
  }
}

class MainTabPageState extends State<MainTabPage> with TickerProviderStateMixin {
  late TabController _mainTabController;
  int _currentIndex = 0;
  bool _isLoggedIn = false;
  String? _avatarUrl;
  bool _isVip = false; // Added VIP state

  set currentIndex(int index) {
    if (index == 3) {
      _checkLoginStatus();
    }
    setState(() {
      _currentIndex = index;
      _mainTabController.index = index;
    });
  }

  int get currentIndex => _currentIndex;
  bool get isLoggedIn => _isLoggedIn;
  String? get avatarUrl => _avatarUrl;
  bool get isVip => _isVip; // Expose isVip

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _mainTabController = TabController(length: 4, vsync: this, initialIndex: _currentIndex);
    _mainTabController.addListener(() {
        if (_mainTabController.indexIsChanging) return;
        if (_mainTabController.index != _currentIndex) {
            setState(() {
                _currentIndex = _mainTabController.index;
            });
            if (_currentIndex == 3) _checkLoginStatus();
        }
    });
    
    if (widget.forceLogout) {
      _isLoggedIn = false;
      _avatarUrl = null;
      _isVip = false;
    } else {
      _checkLoginStatus();
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeUser();
      _checkPendingPurchaseOnStartup();
      _validateSession();
    });

    NotificationService().init();
    _setupNotifications();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  void _setupNotifications() {
     FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleNotificationMessage(message);
    });

    NotificationService().messageStream.listen((message) {
      _handleNotificationMessage(message);
    });
  }

  void _handleNotificationMessage(RemoteMessage message) {
      final isTapped = message.data['tapped'] == 'true';
      final type = message.data['type'];
      print('🔔 Notification Received: ${message.data}');

      if (type == 'wallet_colors') {
        final colorsStr = message.data['colors'];
        if (colorsStr != null && colorsStr.toString().isNotEmpty) {
           final colors = colorsStr.toString().split(',').where((c) => c.isNotEmpty).toList();
           if (colors.isNotEmpty) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) WalletColorBottomSheet.show(context, colors);
             });
           }
        }
      } else if (message.data['article_slug'] != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ArticleDetailPage(slug: message.data['article_slug'])));
              }
          });
      } else if (isTapped) { // Default fallback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const NotificationListPage(isBottomSheet: true),
              );
            }
          });
      }
  }

  Future<void> _checkPendingPurchaseOnStartup() async {
    final pending = await AuthService.getPendingPurchase();
    if (pending != null) {
      setState(() { _currentIndex = 2; });
    }
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    int version = 1;
    String title = 'ยินดีต้อนรับ!';
    String body = 'ขอต้อนรับสู่ NumberNiceIC\nแอพพลิเคชันวิเคราะห์ชื่อและเบอร์โทรศัพท์มงคล\nที่จะช่วยเสริมสิริมงคลให้กับชีวิตของคุณ';
    bool isActive = true;

    try {
      final apiConfig = await ApiService.getWelcomeMessage();
      if (apiConfig != null) {
        version = apiConfig['version'] ?? 1;
        title = apiConfig['title'] ?? title;
        body = (apiConfig['body'] ?? body).replaceAll('\\n', '\n');
        isActive = apiConfig['is_active'] ?? true;
      }
    } catch (_) {}

    if (!isActive) return;

    final int lastShownVersion = prefs.getInt('welcome_msg_version') ?? 0;
    if (version > lastShownVersion) {
      if (!mounted) return;
      await WelcomeDialog.show(context: context, title: title, body: body, version: version);
    }
  }

  Future<void> _checkLoginStatus() async {
    final userInfo = await AuthService.getUserInfo();
    if (mounted) {
      setState(() {
        _isLoggedIn = userInfo['username'] != null;
        _isVip = userInfo['is_vip'] == true || userInfo['tier'] == 'vip'; // Sync VIP status
        _avatarUrl = userInfo['avatar_url'];
      });
    }
  }

  Future<void> _validateSession() async {
    if (_isLoggedIn) {
       try {
         await ApiService.getDashboard(); 
         final token = await FirebaseMessaging.instance.getToken();
         if (token != null) await ApiService.saveDeviceToken(token);
       } catch (e) {
         final stillLoggedIn = await AuthService.isLoggedIn();
         if (!stillLoggedIn && mounted) {
            setState(() {
              _isLoggedIn = false;
              _avatarUrl = null;
            });
         }
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the last page based on login status
    final Widget dashboardPage = _isLoggedIn ? const DashboardPage() : const LoginPage();
    
    final List<Widget> pages = [
      HomeTab(initialName: widget.initialName, initialDay: widget.initialDay),      // Tab 0: Home (with Sub-Menu)
      const LandingPage(),  // Tab 1: Articles
      const ShopPage(),     // Tab 2: Shop
      dashboardPage,        // Tab 3: Menu
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: false, // Changed from true
      appBar: AppBar(
        // ... (App Bar content remains same, just ensuring context)
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
          child: Image.asset(
            'assets/images/chuedee-logo2.png',
            fit: BoxFit.contain,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text('ชื่อดี.com', 
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.kanit(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B), 
                  fontWeight: FontWeight.bold, 
                  fontSize: 22
              )),
            ),
            ],
        ),
        actions: [
            const BuddhistDayBadge(),
            IconButton(
              icon: Icon(Icons.grid_view_rounded, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF64748B)),
              onPressed: () {
                NumberAnalysisPage.show(context);
              },
            ),
            // Notification Bell with badge count
            NotificationBell(iconColor: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF64748B)),
            const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildGlassTopBar(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
          ),
        ],
      ),
      // bottomNavigationBar: _buildGlassBottomBar(), // Removed
    );
  }

  Widget _buildGlassTopBar() {
    return Container(
      margin: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 2,
        bottom: 6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark 
                  ? [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)]
                  : [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.9)],
              ),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'หน้าแรก'),
                _buildNavItem(1, Icons.article_rounded, Icons.article_outlined, 'บทความ'),
                _buildNavItem(2, Icons.storefront_rounded, Icons.storefront_outlined, 'ร้านชื่อดี'),
                _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, _isLoggedIn ? 'เมนู' : 'เข้าสู่ระบบ'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final bool isActive = _currentIndex == index;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tab-specific colors (Light mode uses darker shades for contrast)
    final List<Color> activeColors = isDark 
      ? [
          const Color(0xFFFFD700), // Gold
          const Color(0xFF60A5FA), // Blue
          const Color(0xFF34D399), // Green
          const Color(0xFFF472B6), // Pink
        ]
      : [
          const Color(0xFFD97706), // Amber 600 (Darker Gold)
          const Color(0xFF2563EB), // Blue 600
          const Color(0xFF059669), // Emerald 600
          const Color(0xFFDB2777), // Pink 600
        ];
    
    final Color accentColor = activeColors[index];
    
    return GestureDetector(
      onTap: () {
        if (index == 3) _checkLoginStatus();
        setState(() {
          _currentIndex = index;
          _mainTabController.index = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isActive ? accentColor.withOpacity(0.2) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with glow effect when active
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              child: index == 3 && _isLoggedIn && _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? accentColor : Colors.white38,
                              width: isActive ? 2.5 : 1.5,
                            ),
                            boxShadow: isActive ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ] : null,
                          ),
                          child: ClipOval(
                            child: Image.network(
                              _avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                activeIcon,
                                size: 18,
                                color: isActive ? accentColor : Colors.white38,
                              ),
                            ),
                          ),
                        ),
                        if (_isVip)
                          Positioned(
                            top: -6,
                            right: -8,
                            child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                               decoration: BoxDecoration(
                                 color: const Color(0xFFFFD700),
                                 borderRadius: BorderRadius.circular(6),
                                 border: Border.all(color: Colors.black87, width: 1),
                                 boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
                               ),
                               child: Text('VIP', style: GoogleFonts.kanit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black87, height: 1)),
                            ),
                          ),
                      ],
                    )
                  : ShaderMask(
                      shaderCallback: (bounds) => isActive
                          ? LinearGradient(
                              colors: [accentColor, accentColor.withOpacity(0.8)],
                            ).createShader(bounds)
                          : LinearGradient(
                              colors: Theme.of(context).brightness == Brightness.dark
                                  ? [Colors.white38, Colors.white38]
                                  : [const Color(0xFF94A3B8), const Color(0xFF94A3B8)], // Slate 400
                            ).createShader(bounds),
                      child: Icon(
                        isActive ? activeIcon : inactiveIcon,
                        size: isActive ? 22 : 18,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: GoogleFonts.kanit(
                fontSize: isActive ? 11 : 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                height: 1.1,
                color: isActive 
                    ? accentColor 
                    : (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF64748B)),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

}



class HomeTab extends StatefulWidget {
  final String? initialName;
  final String? initialDay;
  const HomeTab({super.key, this.initialName, this.initialDay});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  int _subIdx = 0; // Default to 'ตั้งชื่อดี' (Naming) which is index 0
  final AnalyzerViewModel _sharedViewModel = AnalyzerViewModel();
  final TextEditingController _nameController = TextEditingController();
  late Future<List<SampleName>> _sampleNamesFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _sampleNamesFuture = ApiService.getSampleNames();
    
    // Initialize with passed values
    if (widget.initialName != null || widget.initialDay != null) {
       _sharedViewModel.init(widget.initialName, widget.initialDay);
    }

    _sharedViewModel.addListener(_onViewModelUpdate);
    // Initialize TabController to sync with _subIdx
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
         setState(() {
           _subIdx = _tabController.index;
         });
      }
    });

    // Show tutorial if name is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🎯 Tutorial Check: currentName="${_sharedViewModel.currentName}", isEmpty=${_sharedViewModel.currentName.isEmpty}');
      if (_sharedViewModel.currentName.isEmpty) {
        print('✅ Setting showTutorial = true');
        _sharedViewModel.setShowTutorial(true);
      } else {
        print('❌ Name not empty, tutorial will not show');
      }
    });
  }

  void _onViewModelUpdate() {
    if (mounted) {
       // Sync text controller if it differs
       if (_nameController.text != _sharedViewModel.currentName) {
         _nameController.text = _sharedViewModel.currentName;
         if (_nameController.selection.baseOffset == -1 && _nameController.text.isNotEmpty) {
            _nameController.selection = TextSelection.fromPosition(TextPosition(offset: _nameController.text.length));
         }
       }
       // Always rebuild to reflect other VM changes (loading, etc)
       // Use addPostFrameCallback to avoid setState during build
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) setState(() {});
       });
    }
  }

  @override
  void dispose() {
    _sharedViewModel.removeListener(_onViewModelUpdate);
    _sharedViewModel.dispose();
    _nameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pages must consume _sharedViewModel efficiently
    return NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // 1. Shared Search Form (Scrolls away)
            SliverToBoxAdapter(
              child: SharedSearchForm(viewModel: _sharedViewModel, nameController: _nameController),
            ),

            // 2. Sub Menu Bar + Samples (Combined Sticky Header)
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  minHeight: 150.0, // 70 (Tabs) + 80 (Samples)
                  maxHeight: 150.0,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A2E) : Colors.white,
                    ),
                    child: Column(
                      children: [
                        // Tabs
                        SizedBox(
                          height: 70, // 70
                          child: Row(
                            children: [
                              Expanded(child: _buildSubMenuItem(0, Icons.edit_note_rounded, 'ตั้งชื่อดี')),
                              Expanded(child: _buildSubMenuItem(1, Icons.auto_awesome_rounded, 'วิเคราะห์ชื่อดี')),
                              Expanded(child: _buildSubMenuItem(2, Icons.trending_up_rounded, 'เสริมชื่อดี')), 
                            ],
                          ),
                        ),
                        // Samples
                        Expanded(
                          child: CustomPaint(
                             painter: BackgroundPatternPainter(opacity: 0.15),
                             child: Container(
                                color: Colors.transparent,
                                child: SharedSampleNames(viewModel: _sharedViewModel, nameController: _nameController, sampleNamesFuture: _sampleNamesFuture)
                             ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: IndexedStack(
          index: _subIdx,
          children: [
             TickerMode(enabled: _subIdx == 0, child: NamingPage(viewModel: _sharedViewModel)),            // 0
             TickerMode(enabled: _subIdx == 1, child: UnlimitedAnalyzerPage(
               key: const ValueKey('unlimited_reload_v1'),
               viewModel: _sharedViewModel,
               onNavigateToNaming: () {
                 setState(() { 
                    _subIdx = 0; 
                    _tabController.animateTo(0);
                 });
               },
             )), // 1
             TickerMode(enabled: _subIdx == 2, child: ShopPage(viewModel: _sharedViewModel)),              // 2
          ],
        ),
    );
  }

  Widget _buildSubMenuItem(int index, IconData icon, String label) {
    final isSelected = _subIdx == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Define Theme Colors (Gradient Start/End)
    Color startColor, endColor, shadowColor;
    
    switch (index) {
      case 0: // ตั้งชื่อดี
        startColor = const Color(0xFF3B82F6); 
        endColor = const Color(0xFF1D4ED8); 
        shadowColor = const Color(0xFF3B82F6).withOpacity(0.5);
        break;
      case 1: // ชื่อ +3 แสน (was 2)
        startColor = const Color(0xFFA855F7); 
        endColor = const Color(0xFF7E22CE);  
        shadowColor = const Color(0xFFA855F7).withOpacity(0.5);
        break;
      case 2: // เสริมชื่อดี (was 3)
        startColor = const Color(0xFFFFD700); 
        endColor = const Color(0xFFF59E0B);  
        shadowColor = const Color(0xFFFFD700).withOpacity(0.5);
        break;
      default:
        startColor = Colors.grey;
        endColor = Colors.grey;
        shadowColor = Colors.black12;
    }

    // Colors
    final Color iconColor = isSelected 
        ? Colors.white 
        : (isDark ? Colors.white70 : const Color(0xFF64748B));
    final Color textColor = isSelected 
        ? Colors.white 
        : (isDark ? Colors.white70 : const Color(0xFF475569));
    final Color borderColor = isSelected 
        ? Colors.white.withOpacity(0.5) 
        : (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0));
    
    // Inactive Gradient/Color
    final inactiveDecoration = isDark
        ? BoxDecoration( // Dark Mode Inactive
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight
            ),
            border: Border.all(color: borderColor, width: 1.0),
          )
        : BoxDecoration( // Light Mode Inactive
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
            ]
          );

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _subIdx = index;
          _tabController.animateTo(index);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: isSelected ? 4 : 8), // Expand active item slightly
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: isSelected 
            ? BoxDecoration( // Active
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [startColor, endColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                   BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 4), spreadRadius: 1)
                ]
              )
            : inactiveDecoration,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: isSelected ? 26 : 22), 
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.kanit(
                  fontSize: 12, 
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _StickyTabBarDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return true;
  }
}
