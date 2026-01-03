import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'นโยบายความเป็นส่วนตัว',
          style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF333333),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              'นโยบายความเป็นส่วนตัว (Privacy Policy)',
              style: GoogleFonts.kanit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'มีผลบังคับใช้ตั้งแต่วันที่ 1 มกราคม 2568',
              style: GoogleFonts.kanit(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. บทนำ',
              'ชื่อดี.com ("เรา") ให้ความสำคัญกับความเป็นส่วนตัวของคุณ นโยบายนี้อธิบายถึงวิธีการที่เราเก็บรวบรวม ใช้ และเปิดเผยข้อมูลส่วนบุคคลของคุณเมื่อคุณใช้งานแอปพลิเคชันและบริการของเรา',
            ),
            _buildSection(
              '2. ข้อมูลที่เราเก็บรวบรวม',
              'เราอาจเก็บรวบรวมข้อมูลต่อไปนี้:\n'
              '- ข้อมูลที่คุณให้โดยตรง เช่น ชื่อ, วันเกิด, อีเมล เมื่อคุณลงทะเบียน\n'
              '- ข้อมูลการใช้งาน เช่น ประวัติการวิเคราะห์ชื่อและเบอร์โทรศัพท์\n'
              '- ข้อมูลอุปกรณ์และประวัติการเข้าชม',
            ),
            _buildSection(
              '3. วิธีการใช้ข้อมูล',
              'เราใช้ข้อมูลของคุณเพื่อ:\n'
              '- ให้บริการวิเคราะห์และทำนายผลตามที่คุณร้องขอ\n'
              '- ปรับปรุงและพัฒนาบริการของเรา\n'
              '- ติดต่อสื่อสารกับคุณเกี่ยวกับบริการหรือข้อเสนอพิเศษ',
            ),
            _buildSection(
              '4. การเปิดเผยข้อมูล',
              'เราจะไม่ขายหรือให้เช่าข้อมูลส่วนบุคคลของคุณแก่บุคคลภายนอก ยกเว้นกรณีที่ได้รับความยินยอมจากคุณ หรือตามที่กฎหมายกำหนด',
            ),
            _buildSection(
              '5. ความปลอดภัยของข้อมูล',
              'เราใช้มาตรการรักษาความปลอดภัยที่เหมาะสมเพื่อป้องกันการเข้าถึง การใช้ หรือการเปิดเผยข้อมูลของคุณโดยไม่ได้รับอนุญาต',
            ),
            _buildSection(
              '6. สิทธิ์ของคุณ',
              'คุณมีสิทธิ์ในการเข้าถึง แก้ไข หรือลบข้อมูลส่วนบุคคลของคุณ คุณสามารถติดต่อเราเพื่อดำเนินการดังกล่าวได้ตลอดเวลา',
            ),
            _buildSection(
              '7. การลบข้อมูลบัญชี',
              'หากคุณต้องการลบบัญชีผู้ใช้และข้อมูลทั้งหมดของคุณ คุณสามารถทำได้โดยไปที่เมนู "แจ้งขอลบข้อมูลบัญชี" ในแอปพลิเคชัน หรือติดต่อเราผ่านช่องทางที่ระบุไว้',
            ),
            _buildSection(
              '8. การติดต่อเรา',
              'หากมีข้อสงสัยเกี่ยวกับนโยบายความเป็นส่วนตัว สามารถติดต่อเราได้ที่:\n'
              'Email: msaccess2013@gmail.com\n'
              'Tel: 0936544442',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
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
        ],
      ),
    );
  }
}
