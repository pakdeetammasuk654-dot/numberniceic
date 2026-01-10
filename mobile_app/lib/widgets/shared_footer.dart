import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/privacy_policy_page.dart';
import '../screens/delete_account_page.dart';
import '../screens/how_to_order_page.dart';

class SharedFooter extends StatelessWidget {
  final Color? textColor;

  const SharedFooter({super.key, this.textColor});

  @override
  Widget build(BuildContext context) {
    // Web Style Constants
    const darkBg = Color(0xFF1a1a1a);
    const darkerBg = Color(0xFF111111);
    const goldColor = Color(0xFFFFD700);
    const textGray = Color(0xFFaaaaaa); // Brand text
    const textLight = Color(0xFFf0f0f0);
    const iconColor = Color(0xFFcccccc);
    const borderColor = Color(0xFF333333);

    return Column(
      children: [
        // Main Footer Section
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: darkBg,
            border: Border(top: BorderSide(color: goldColor, width: 4)),
          ),
          padding: const EdgeInsets.only(top: 40, bottom: 20, left: 24, right: 24),
          child: Column(
            children: [
              // Brand
              Text(
                'NumberNiceIC',
                style: GoogleFonts.kanit(fontSize: 24, fontWeight: FontWeight.bold, color: goldColor),
              ),
              const SizedBox(height: 12),
              Text(
                'ศาสตร์แห่งตัวเลขเพื่อชีวิตที่ดีกว่า วิเคราะห์ชื่อและเบอร์โทรศัพท์มงคลด้วยหลักเลขศาสตร์สากล แม่นยำ ทันสมัย และเชื่อถือได้',
                textAlign: TextAlign.center,
                style: GoogleFonts.kanit(fontSize: 14, color: textGray, height: 1.5),
              ),
              const SizedBox(height: 20),
              
              // Live Status (Mock)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFF2ECC71).withOpacity(0.5), blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live: ขณะนี้มี 24 ผู้ใช้งานกำลังออนไลน์',
                    style: GoogleFonts.kanit(fontSize: 12, color: const Color(0xFFa0aec0)),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Contact
              _buildContactItem(Icons.email_outlined, 'msaccess2013@gmail.com', iconColor, textLight),
              const SizedBox(height: 12),
              _buildContactItem(Icons.phone_outlined, '0936544442 (คุณทญา)', iconColor, textLight),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/LINE_logo.svg/480px-LINE_logo.svg.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.chat_bubble, color: Color(0xFF06C755), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Line ID: numberniceic',
                    style: GoogleFonts.kanit(fontSize: 14, color: textLight),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              Text(
                 '*ผลการวิเคราะห์เป็นการถอดรหัสพยัญชนะและสระตามตำราการตั้งชื่อโบราณ',
                 textAlign: TextAlign.center,
                 style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),

              // Legal Links
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                runSpacing: 12,
                children: [
                   InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HowToOrderPage()));
                    },
                    child: Text(
                      'วิธีการสั่งซื้อ',
                      style: GoogleFonts.kanit(
                        fontSize: 16, 
                        color: textLight, 
                        decoration: TextDecoration.underline,
                        decorationColor: textLight,
                      ),
                    ),
                  ),
                   InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()));
                    },
                    child: Text(
                      'นโยบายความเป็นส่วนตัว',
                      style: GoogleFonts.kanit(
                        fontSize: 16, 
                        color: textLight, 
                        decoration: TextDecoration.underline,
                        decorationColor: textLight,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DeleteAccountPage()));
                    },
                    child: Text(
                      'แจ้งขอลบข้อมูลบัญชี',
                      style: GoogleFonts.kanit(
                        fontSize: 16, 
                        color: textLight, 
                        decoration: TextDecoration.underline,
                        decorationColor: textLight,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
        
        // Copyright Section
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: darkerBg,
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Text(
             '© 2025 NumberNiceIC. All Rights Reserved.',
             textAlign: TextAlign.center,
             style: GoogleFonts.kanit(fontSize: 12, color: const Color(0xFF888888)),
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem(IconData icon, String text, Color iconColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.kanit(fontSize: 14, color: textColor),
        ),
      ],
    );
  }
}
