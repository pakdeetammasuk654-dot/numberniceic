import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/upgrade_dialog.dart';
import '../widgets/shared_footer.dart';


class NumerologyDetailPage extends StatelessWidget {
  final String name;
  final List decodedParts;
  final List uniquePairs;
  final bool isVip;
  final VoidCallback onUpgrade;

  const NumerologyDetailPage({
    super.key,
    required this.name,
    required this.decodedParts,
    required this.uniquePairs,
    required this.isVip,
    required this.onUpgrade,
  });

  Color _getPairColor(String type) {
    switch (type) {
      case 'D10': return const Color(0xFF2E7D32);
      case 'D8': return const Color(0xFF43A047);
      case 'D5': return const Color(0xFF66BB6A);
      case 'R10': return const Color(0xFFC62828);
      case 'R7': return const Color(0xFFD32F2F);
      case 'R5': return const Color(0xFFE57373);
      default: return Colors.grey;
    }
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isBad = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.kanit(
          fontSize: 14,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isBad ? Colors.red : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMeaningItem(Map p) {
    final color = _getPairColor(p['meaning']['pair_type']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(p['pair_number'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['meaning']['miracle_desc'] ?? '', style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                Text(p['meaning']['miracle_detail'] ?? '', style: GoogleFonts.sarabun(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ชื่อ: $name', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF333333),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('เลขศาสตร์ พลังเงา', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Table(
                    border: TableBorder.all(color: Colors.grey[300]!),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey[100]),
                        children: [
                          _buildCell('ตัวอักษร', isHeader: true),
                          _buildCell('เลขศาสตร์', isHeader: true),
                          _buildCell('พลังเงา', isHeader: true),
                        ],
                      ),
                      ...decodedParts.map((part) => TableRow(
                            children: [
                              _buildCell(part['character'], isBad: part['is_klakini']),
                              _buildCell(part['numerology_value'].toString()),
                              _buildCell(part['shadow_value'].toString()),
                            ],
                          )),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('ความหมายเลข', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...uniquePairs.asMap().entries.map((entry) {
                     final idx = entry.key;
                     final p = entry.value;
                     if (!isVip && idx > 2) return const SizedBox.shrink();
                     
                     bool shouldBlur = !isVip && idx == 2;

                     Widget item = _buildMeaningItem(p);
                     
                     if (shouldBlur) {
                       return ImageFiltered(
                         imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                         child: item,
                       );
                     }
                     return item;
                  }).toList(),
                  
                  if (!isVip && uniquePairs.length > 2) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber[200]!),
                            ),
                            child: Column(
                              children: [
                                Text('🔒 เนื้อหานี้สำหรับสมาชิก VIP', 
                                  style: GoogleFonts.kanit(color: Colors.amber[900], fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: onUpgrade,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: Text('อัปเกรดแบบถาวรเพื่อดูทั้งหมด', style: GoogleFonts.kanit()),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SharedFooter(),
          ],
        ),
      ),
    );
  }
}
