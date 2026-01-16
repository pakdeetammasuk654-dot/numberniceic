
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../utils/custom_toast.dart';
import 'main_tab_page.dart';
import 'package:flutter/services.dart'; // Import for MethodChannel
import '../widgets/shared_footer.dart';
import 'line_direct_login_page.dart'; // Direct Login WebView

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  String _loadingProvider = '';
  @override
  void initState() {
    super.initState();
    // _printAppSignature(); // Removed debug signature check
  }

  // Method Channel removed as usage is commented out

  // Handle LINE Login via Native SDK (with smart fallback)
  Future<void> _handleLineSDK() async {
    setState(() {
      _isLoading = true;
      _loadingProvider = 'line';
    });

    final result = await AuthService.loginWithLine();

    // Check if we need to use WebView instead (for Android 9 and below)
    if (result['use_webview'] == true) {
      setState(() {
        _isLoading = false;
        _loadingProvider = '';
      });
      
      // Automatically fallback to WebView
      print("🔄 Falling back to WebView for compatibility");
      await _handleLineDirect();
      return;
    }

    setState(() {
      _isLoading = false;
      _loadingProvider = '';
    });

    if (result['success']) {
      if (mounted) {
        CustomToast.show(context, 'เข้าสู่ระบบสำเร็จ ยินดีต้อนรับ!');
        
        final pending = await AuthService.getPendingPurchase();
        int targetIndex = pending != null ? 2 : 3;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => MainTabPage(initialIndex: targetIndex)),
          (Route<dynamic> route) => false,
        );
      }
    } else {
      if (mounted) {
        CustomToast.show(context, result['message'] ?? 'เข้าสู่ระบบไม่สำเร็จ', isSuccess: false);
      }
    }
  }

  // Handle Direct LINE Login via WebView (Fallback)
  Future<void> _handleLineDirect() async {
    // 1. Open WebView Login
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const LineDirectLoginPage()),
    );

    if (result != null && result is Map) {
      if (result['code'] != null) {
        // 2. Got Code -> Exchange for Token & Login
        await _handleSocialLogin('line', () => AuthService.handleLineDirectLogin(result['code']));
      } else if (result['error'] != null) {
        if (mounted) CustomToast.show(context, 'LINE Login Error: ${result['error']}', isSuccess: false);
      }
    }
  }

  Future<void> _handleSocialLogin(String provider, Future<Map<String, dynamic>> Function() loginFunction) async {
    setState(() {
      _isLoading = true;
      _loadingProvider = provider;
    });

    final result = await loginFunction();

    setState(() {
      _isLoading = false;
      _loadingProvider = '';
    });

    if (result['success']) {
      if (mounted) {
        CustomToast.show(context, 'เข้าสู่ระบบสำเร็จ ยินดีต้อนรับ!');
        
        final pending = await AuthService.getPendingPurchase();
        int targetIndex = pending != null ? 2 : 3;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => MainTabPage(initialIndex: targetIndex)),
          (Route<dynamic> route) => false,
        );
      }
    } else {
      if (mounted) {
        CustomToast.show(context, result['message'] ?? 'เข้าสู่ระบบไม่สำเร็จ', isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header Icon & Title
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667EEA).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/chuedee-logo2.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'เข้าสู่ระบบ',
                        style: GoogleFonts.kanit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            const Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black26),
                          ],
                        ),
                      ),
                      Text(
                        'เลือกวิธีการเข้าสู่ระบบ',
                        style: GoogleFonts.kanit(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 40),

                      // Social Login Buttons Container
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1F2687).withOpacity(0.37),
                              blurRadius: 32,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Google Login Button
                            _buildSocialButton(
                              provider: 'google',
                              label: 'เข้าสู่ระบบด้วย Google',
                              icon: Icons.g_mobiledata_rounded,
                              backgroundColor: Colors.white,
                              textColor: const Color(0xFF333333),
                              iconColor: const Color(0xFF4285F4),
                              onPressed: () => _handleSocialLogin('google', AuthService.loginWithGoogle),
                            ),
                            const SizedBox(height: 16),

                            // Facebook Login Button
                            _buildSocialButton(
                              provider: 'facebook',
                              label: 'เข้าสู่ระบบด้วย Facebook',
                              icon: Icons.facebook,
                              backgroundColor: const Color(0xFF1877F2),
                              textColor: Colors.white,
                              iconColor: Colors.white,
                              onPressed: () => _handleSocialLogin('facebook', AuthService.loginWithFacebook),
                            ),
                            const SizedBox(height: 16),

                            // LINE Login Button (Native SDK)
                            _buildSocialButton(
                              provider: 'line',
                              label: 'เข้าสู่ระบบด้วย LINE',
                              icon: Icons.chat_bubble,
                              backgroundColor: const Color(0xFF00B900),
                              textColor: Colors.white,
                              iconColor: Colors.white,
                              onPressed: _handleLineSDK, // Use Native SDK
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Privacy Notice
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'เราจะไม่เก็บรหัสผ่านของคุณ\nข้อมูลจะถูกเข้ารหัสอย่างปลอดภัย',
                                style: GoogleFonts.sarabun(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Footer
                Opacity(opacity: 0.7, child: const SharedFooter(textColor: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String provider,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    final isCurrentlyLoading = _isLoading && _loadingProvider == provider;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isCurrentlyLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: textColor,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.kanit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
