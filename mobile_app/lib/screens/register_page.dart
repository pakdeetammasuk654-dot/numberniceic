import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../utils/custom_toast.dart';
import '../widgets/shared_footer.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _register() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      CustomToast.show(context, 'รหัสผ่านไม่ตรงกัน', isSuccess: false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.register(
      _usernameController.text.trim(),
      _passwordController.text,
      _emailController.text.trim(),
      _telController.text.trim(),
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      if (mounted) {
        // Show success toast and go back to login
        CustomToast.show(context, 'สมัครสมาชิกสำเร็จ! กรุณาเข้าสู่ระบบด้วยบัญชีใหม่ของคุณ');
        Navigator.pop(context); // Back to Login Page
      }
    } else {
      if (mounted) {
        CustomToast.show(context, result['message'] ?? 'สมัครสมาชิกไม่สำเร็จ', isSuccess: false);
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  'ลงทะเบียน',
                  style: GoogleFonts.kanit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      const Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                ),
                Text(
                  'สร้างบัญชีใหม่สำหรับ ชื่อดี.com',
                  style: GoogleFonts.kanit(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 32),

                // Glassmorphism Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('ชื่อผู้ใช้ (Username)'),
                      const SizedBox(height: 8),
                      _buildInputField(_usernameController, 'ชื่อผู้ใช้ (ไทย/Eng)', Icons.person_outline),
                      const SizedBox(height: 16),
                      
                      _buildLabel('รหัสผ่าน (Password)'),
                      const SizedBox(height: 8),
                      _buildInputField(_passwordController, 'Choose a password', Icons.lock_outline, isObscure: true),
                      const SizedBox(height: 16),
                      
                      _buildLabel('ยืนยันรหัสผ่าน (Confirm Password)'),
                      const SizedBox(height: 8),
                      _buildInputField(_confirmPasswordController, 'Confirm your password', Icons.lock_outline, isObscure: true),
                      const SizedBox(height: 16),
                      
                      _buildLabel('อีเมล (Email)'),
                      const SizedBox(height: 8),
                      _buildInputField(_emailController, 'Optional', Icons.email_outlined, isEmail: true),
                      const SizedBox(height: 16),
                      
                      _buildLabel('เบอร์โทรศัพท์ (Telephone)'),
                      const SizedBox(height: 8),
                      _buildInputField(_telController, 'Optional', Icons.phone_iphone, isNumber: true),
                      const SizedBox(height: 32),
                      
                      // Gradient Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFBA00), Color(0xFFFF8C00)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF8C00).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'ลงทะเบียน (Register)',
                                  style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('มีบัญชีอยู่แล้ว? ', style: GoogleFonts.kanit(color: Colors.white70)),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'เข้าสู่ระบบที่นี่',
                        style: GoogleFonts.kanit(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFBA00),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                    ],
                  ),
                ),
                // Footer - full width outside padding
                Opacity(opacity: 0.7, child: const SharedFooter(textColor: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.kanit(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hintText, IconData icon, {bool isObscure = false, bool isEmail = false, bool isNumber = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: isEmail ? TextInputType.emailAddress : (isNumber ? TextInputType.phone : TextInputType.text),
      style: GoogleFonts.sarabun(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        hintText: hintText,
        hintStyle: GoogleFonts.sarabun(color: Colors.white60),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        prefixIcon: Icon(icon, color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.8)),
        ),
      ),
    );
  }
}
