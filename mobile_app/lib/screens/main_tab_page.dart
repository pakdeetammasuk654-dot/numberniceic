import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final userInfo = await AuthService.getUserInfo();
    if (mounted) {
      setState(() {
        _isLoggedIn = userInfo['username'] != null;
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
              icon: Icon(_isLoggedIn ? Icons.dashboard_outlined : Icons.login_outlined),
              activeIcon: Icon(_isLoggedIn ? Icons.dashboard : Icons.login),
              label: _isLoggedIn ? 'แดชบอร์ด' : 'เข้าสู่ระบบ',
            ),
          ],
        ),
      ),
    );
  }
}
