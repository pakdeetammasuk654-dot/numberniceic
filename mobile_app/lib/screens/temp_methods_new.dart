
  Widget _buildAnalysisExplanation() {
    return Container(
      key: const ValueKey('explanation'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
         children: [
            Text(
              "หลักการวิเคราะห์และน้ำหนักตัวเลข",
              style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            Text(
              "การพยากรณ์จะให้น้ำหนักตามตำแหน่งของตัวเลข\nโดยแบ่งความสำคัญดังนี้",
              textAlign: TextAlign.center,
              style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            
            // Visual Diagram
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                    // Prefix (0XX)
                    Expanded(
                       flex: 2,
                       child: _buildWeightBar(
                         label: "0XX",
                         percent: "0%",
                         desc: "เครือข่าย",
                         color: Colors.grey[300]!,
                         textColor: Colors.grey[500]!,
                         heightFactor: 0.3,
                       ),
                    ),
                    const SizedBox(width: 8),
                    // Front (XXX)
                    Expanded(
                       flex: 3,
                       child: _buildWeightBar(
                         label: "XXX",
                         percent: "30%",
                         desc: "บุคลิกภาพ",
                         color: const Color(0xFF60A5FA), // Blue
                         textColor: const Color(0xFF2563EB),
                         heightFactor: 0.6,
                       ),
                    ),
                    const SizedBox(width: 8),
                    // Back (XXXX)
                    Expanded(
                       flex: 4,
                       child: _buildWeightBar(
                         label: "XXXX",
                         percent: "70%",
                         desc: "หัวใจหลัก",
                         color: const Color(0xFFF59E0B), // Gold
                         textColor: const Color(0xFFD97706),
                         heightFactor: 1.0,
                         isHighlight: true,
                       ),
                    ),
                 ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Text Detail
            Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                     BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                  ]
               ),
               child: Column(
                  children: [
                     _buildDetailRow(
                        color: Colors.grey[400]!, 
                        title: "3 ตัวหน้า (0XX)", 
                        detail: "คือรหัสเครือข่าย ไม่มีผลต่อคำทำนาย"
                     ),
                     const SizedBox(height: 12),
                     _buildDetailRow(
                        color: const Color(0xFF60A5FA), 
                        title: "3 ตัวกลาง (XXX)", 
                        detail: "ส่งผลถึงภาพลักษณ์ภายนอก บุคลิกส่วนตัว และการเริ่มต้น"
                     ),
                     const SizedBox(height: 12),
                     _buildDetailRow(
                        color: const Color(0xFFF59E0B), 
                        title: "4 ตัวท้าย (XXXX)", 
                        detail: "สำคัญที่สุด! ควบคุมชะตาชีวิต การเงิน ความรัก และบทสรุป",
                        isHighlight: true
                     ),
                  ],
               ),
            ),
            const SizedBox(height: 40),
         ],
      ),
    );
  }

  Widget _buildWeightBar({
    required String label, 
    required String percent, 
    required String desc, 
    required Color color, 
    required Color textColor,
    required double heightFactor,
    bool isHighlight = false,
  }) {
     return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
           Text(percent, style: GoogleFonts.kanit(fontSize: isHighlight ? 20 : 16, fontWeight: FontWeight.bold, color: textColor)),
           const SizedBox(height: 4),
           Container(
              height: 60 * heightFactor,
              width: double.infinity,
              decoration: BoxDecoration(
                 color: color.withOpacity(0.2),
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(color: color, width: isHighlight ? 2 : 1),
              ),
              alignment: Alignment.center,
              child: Text(label, style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: textColor)),
           ),
           const SizedBox(height: 8),
           Text(desc, style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center, maxLines: 1),
        ],
     );
  }

  Widget _buildDetailRow({required Color color, required String title, required String detail, bool isHighlight = false}) {
     return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
              margin: const EdgeInsets.only(top: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
           ),
           const SizedBox(width: 12),
           Expanded(
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(title, style: GoogleFonts.kanit(fontSize: 15, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFFD97706) : const Color(0xFF374151))),
                    const SizedBox(height: 2),
                    Text(detail, style: GoogleFonts.kanit(fontSize: 13, color: Colors.grey[600], height: 1.4)),
                 ],
              ),
           )
        ],
     );
  }
