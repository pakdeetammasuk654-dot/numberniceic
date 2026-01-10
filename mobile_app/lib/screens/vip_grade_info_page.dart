import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/shared_footer.dart';
import '../widgets/adaptive_footer_scroll_view.dart';

class VipGradeInfoPage extends StatelessWidget {
  const VipGradeInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ระดับความมงคล (VIP Grade)',
          style: GoogleFonts.kanit(),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: AdaptiveFooterScrollView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'เมื่อวิเคราะห์เบอร์โทรศัพท์ ระบบจะให้เกรดความมงคลโดยพิจารณาจาก "ความต่อเนื่องของคู่เลขดี" (Consecutive Good Pairs) โดยเริ่มไล่จาก คู่สุดท้าย ย้อนกลับมาหาคู่แรก ยิ่งมีคู่ดีติดต่อกันมากเท่าไหร่ ระดับความมงคลยิ่งสูงขึ้นเท่านั้น',
            style: GoogleFonts.sarabun(fontSize: 16, height: 1.6, color: Colors.grey[800]),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey[200]!),
                ),
                children: [
                  // Header
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey[50]),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('ระดับ (Grade)', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('เงื่อนไข (Condition)', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                      ),
                    ],
                  ),
                  // PERFECT
                  _buildRow(
                    'PERFECT',
                    'ผลรวมดี + คู่เลขดีต่อเนื่องกัน 5 คู่ขึ้นไป (แทบไม่มีที่ติ)',
                    const Color(0xFFFEF3C7), const Color(0xFF92400E)
                  ),
                  // The Best
                  _buildRow(
                    'The Best',
                    'ผลรวมดี + คู่เลขดีต่อเนื่องกัน 4 คู่',
                    const Color(0xFFF3E8FF), const Color(0xFF6B21A8)
                  ),
                  // Triple Good
                  _buildRow(
                    'Triple ดี',
                    'ผลรวมดี + คู่เลขดีต่อเนื่องกัน 3 คู่',
                    const Color(0xFFDBEAFE), const Color(0xFF1E40AF)
                  ),
                  // Double Good
                  _buildRow(
                    'คู่ท้าย Double ดี',
                    'ผลรวมดี + คู่เลขดีต่อเนื่องกัน 2 คู่ (ปิดท้ายสวยงาม)',
                    const Color(0xFFDCFCE7), const Color(0xFF166534)
                  ),
                   // Single Good
                  _buildRow(
                    'คู่ท้ายดี',
                    'ผลรวมดี + คู่เลขสุดท้ายเป็นคู่ดี 1 คู่',
                    const Color(0xFFF3F4F6), const Color(0xFF1F2937)
                  ),
                  // Sum Good
                  _buildRow(
                    'ผลรวมดี',
                    'ผลรวม (Sum) ออกมาดี แต่คู่ท้ายอาจยังไม่สมบูรณ์ หรือขาดความต่อเนื่อง',
                    const Color(0xFFF9FAFB), const Color(0xFF6B7280)
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '"หลักการนี้ช่วยให้คุณเห็นภาพว่า การเสริมเบอร์มงคล คือการเข้ามา \'เติมเต็ม\' ส่วนที่ขาดหายไปในชีวิตให้สมบูรณ์ยิ่งขึ้น"',
              style: GoogleFonts.sarabun(
                fontSize: 16, 
                fontWeight: FontWeight.bold, 
                color: const Color(0xFF92400E),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildRow(String grade, String condition, Color bg, Color text) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                grade,
                style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: text),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            condition,
            style: GoogleFonts.sarabun(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}
