import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/welcome_dialog.dart';
import 'landing_page.dart';
import 'analyzer_page.dart';
import 'number_analysis_page.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'shop_page.dart';

class MainTabPage extends StatefulWidget {
  final int initialIndex;
  const MainTabPage({super.key, this.initialIndex = 0});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _currentIndex = 0;
  bool _isLoggedIn = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkLoginStatus();
    // Check for first time launch after UI builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeUser();
    });
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Default Fallback
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
    final bool hasShownLegacy = prefs.getBool('has_shown_welcome_v1') ?? false;

    // Convert legacy boolean to version 1 if applicable
    if (lastShownVersion == 0 && hasShownLegacy && version == 1) {
       await prefs.setInt('welcome_msg_version', 1);
       return;
    }

    if (version > lastShownVersion) {
      if (!mounted) return;
      await WelcomeDialog.show(
        context: context,
        title: title,
        body: body,
        version: version,
      );
    }
  }

  Future<void> _checkLoginStatus() async {
    final userInfo = await AuthService.getUserInfo();
    if (mounted) {
      setState(() {
        _isLoggedIn = userInfo['username'] != null;
        _avatarUrl = userInfo['avatar_url'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the last page based on login status
    final Widget dashboardPage = _isLoggedIn ? const DashboardPage() : const LoginPage();
    
    final List<Widget> pages = [
      const LandingPage(),
      const AnalyzerPage(),
      const NumberAnalysisPage(),
      const ShopPage(),
      dashboardPage,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF333333),
          currentIndex: _currentIndex,
          onTap: (index) async {
              // Now Dashboard/Login is index 4
              if(index == 4) {
                  await _checkLoginStatus(); 
              }
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.5),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.kanit(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.kanit(fontSize: 12),
          elevation: 20,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'หน้าแรก',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.badge_outlined),
              activeIcon: Icon(Icons.badge),
              label: 'วิเคราะห์ชื่อ',
            ),
             const BottomNavigationBarItem(
              icon: Icon(Icons.dialpad_outlined),
              activeIcon: Icon(Icons.dialpad),
              label: 'วิเคราะห์เบอร์',
            ),
             const BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront),
              label: 'ร้านค้า',
            ),
            BottomNavigationBarItem(
              icon: _buildUserIcon(false),
              activeIcon: _buildUserIcon(true),
              label: _isLoggedIn ? 'แดชบอร์ด' : 'เข้าสู่ระบบ',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 3 
        ? null 
        : FloatingActionButton(
            onPressed: () => setState(() => _currentIndex = 3),
            backgroundColor: Colors.transparent,
            elevation: 10,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFDB931)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.shopping_cart, color: Color(0xFF4A3B00), size: 28),
            ),
          ),
    );
  }
  Widget _buildUserIcon(bool isActive) {
    if (!_isLoggedIn || _avatarUrl == null || _avatarUrl!.isEmpty) {
      return Icon(isActive 
        ? (_isLoggedIn ? Icons.dashboard : Icons.login)
        : (_isLoggedIn ? Icons.dashboard_outlined : Icons.login_outlined)
      );
    }

    final size = isActive ? 26.0 : 24.0;
    final borderWidth = isActive ? 2.0 : 1.0;
    final borderColor = isActive ? Colors.white : Colors.white.withOpacity(0.5);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(
        child: Image.network(
          _avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(isActive ? Icons.dashboard : Icons.dashboard_outlined, size: size * 0.8);
          },
        ),
      ),
    );
  }
}
