import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/shared_footer.dart';
import '../widgets/adaptive_footer_scroll_view.dart';
import 'package:url_launcher/url_launcher.dart';

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'msaccess2013@gmail.com',
      queryParameters: {
        'subject': 'ขอลบข้อมูลบัญชี / Request Account Deletion',
      },
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'แจ้งขอลบข้อมูลบัญชี',
          style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF333333),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AdaptiveFooterScrollView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text(
            'ขอลบข้อมูลบัญชี (Account Deletion)',
            style: GoogleFonts.kanit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'หากคุณต้องการลบบัญชีผู้ใช้และข้อมูลทั้งหมดของคุณจากระบบของ ชื่อดี.com (NumberNiceIC) สามารถดำเนินการได้ดังนี้:',
            style: GoogleFonts.kanit(fontSize: 16, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'ช่องทางแจ้งความประสงค์',
            'โปรดส่งอีเมลเพื่อยืนยันตัวตนและแจ้งลบบัญชีมาที่:',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                InkWell(
                  onTap: _launchEmail,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined, color: Colors.blue),
                        const SizedBox(width: 12),
                        Text(
                          'msaccess2013@gmail.com',
                          style: GoogleFonts.kanit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'โดยระบุหัวข้ออีเมลว่า "ขอลบข้อมูลบัญชี / Request Account Deletion" และแจ้งรายละเอียดบัญชีของคุณ',
                  style: GoogleFonts.kanit(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          _buildSection(
            'ข้อมูลที่จะถูกลบ',
            '• ข้อมูลโปรไฟล์ส่วนตัว (ชื่อ, อีเมล, เบอร์โทรศัพท์)\n'
            '• ประวัติการวิเคราะห์ทั้งหมด\n'
            '• รายชื่อที่บันทึกไว้ (Saved Names)\n'
            '• สิทธิ์การเป็นสมาชิก VIP',
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[100]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'คำเตือน: การดำเนินการลบบัญชีจะไม่สามารถย้อนกลับได้ ข้อมูลจะถูกลบออกอย่างถาวร',
                    style: GoogleFonts.kanit(fontSize: 13, color: Colors.red[900], fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'ระยะเวลาดำเนินการ',
            'ทีมงานจะดำเนินการตรวจสอบและลบข้อมูลของคุณภายใน 7 วันทำการหลังจากได้รับคำร้อง',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, {Widget? child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.kanit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.kanit(
              fontSize: 16,
              color: Colors.black54,
              height: 1.6,
            ),
          ),
          if (child != null) child,
        ],
      ),
    );
  }
}
