import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/adaptive_footer_scroll_view.dart';

class HowToOrderPage extends StatelessWidget {
  const HowToOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'วิธีการสั่งซื้อและสิทธิ์ VIP',
          style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF333333),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AdaptiveFooterScrollView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildHeroSection(),
          const SizedBox(height: 32),
          _buildStepsSection(),
          const SizedBox(height: 40),
          _buildVIPBenefitsSection(),
          const SizedBox(height: 24),
          _buildPaymentTip(),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        const Icon(Icons.shopping_cart_checkout, size: 64, color: Colors.blueAccent),
        const SizedBox(height: 16),
        Text(
          'ขั้นตอนการสั่งซื้อสินค้ามงคล',
          style: GoogleFonts.kanit(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'ชื่อดี.com (NumberNiceIC)',
          style: GoogleFonts.kanit(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepItem(
          '1',
          'เลือกสินค้าที่ต้องการ',
          'เลือกเบอร์โทรศัพท์หรือสินค้ามงคลที่คุณสนใจจากหน้าร้านค้า',
        ),
        _buildStepItem(
          '2',
          'ชำระเงินผ่าน QR Code',
          'ระบบจะสร้าง QR Code สำหรับชำระเงิน คุณสามารถสะแกนจ่ายได้ทันที หรือ Capture หน้าจอเพื่อนำไปจ่ายผ่านแอปธนาคารของคุณ',
        ),
        _buildStepItem(
          '3',
          'รับสิทธิ์ VIP อัตโนมัติ',
          'เมื่อชำระเงินสำเร็จ ระบบจะปรับสถานะบัญชีของคุณเป็น VIP โดยอัตโนมัติ ไม่ต้องกรอกรหัสยืนยันใดๆ',
        ),
      ],
    );
  }

  Widget _buildStepItem(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.kanit(fontSize: 15, color: Colors.black87, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVIPBenefitsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Text(
                'สิทธิพิเศษระดับ VIP',
                style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBenefitItem('วิเคราะห์ชื่อและเบอร์โทรศัพท์แบบเจาะลึก'),
          _buildBenefitItem('เข้าถึงข้อมูลคู่เลขศาสตร์และพลังเงาทั้งหมด'),
          _buildBenefitItem('บันทึกประวัติการวิเคราะห์ได้ไม่จำกัด'),
          _buildBenefitItem('ได้รับสิทธิ์ใช้งานฟีเจอร์ใหม่ๆ ก่อนใคร'),
          _buildBenefitItem('ใช้งานได้นาน 1 ปีเต็ม นับจากวันที่สั่งซื้อ'),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.kanit(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'คำแนะนำ: เมื่อปรากฎหน้า QR Code คุณสามารถ "Capture หน้าจอ" เก็บไว้ แล้วเปิดแอปธนาคารเพื่อเลือก "Scan จ่าย" จากรูปภาพที่บันทึกไว้ได้ทันที',
              style: GoogleFonts.kanit(fontSize: 13, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
