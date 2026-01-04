import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/shared_footer.dart';


class LinguisticDetailPage extends StatelessWidget {
  final String name;
  final String analysisHtml;

  const LinguisticDetailPage({
    super.key,
    required this.name,
    required this.analysisHtml,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ภาษาศาสตร์ของ $name',
          style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF333333),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: MarkdownBody(
                data: analysisHtml,
                styleSheet: MarkdownStyleSheet(
                  h1: GoogleFonts.sarabun(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5, color: const Color(0xFF2D3748)),
                  h2: GoogleFonts.sarabun(fontSize: 20, fontWeight: FontWeight.bold, height: 1.5, color: const Color(0xFF2D3748)),
                  h3: GoogleFonts.sarabun(fontSize: 18, fontWeight: FontWeight.bold, height: 1.5, color: const Color(0xFF2D3748)),
                  p: GoogleFonts.sarabun(fontSize: 16, height: 1.8, color: const Color(0xFF4A5568)),
                  listBullet: GoogleFonts.sarabun(fontSize: 16, height: 1.8, color: const Color(0xFF4A5568)),
                  strong: GoogleFonts.sarabun(fontWeight: FontWeight.bold, color: const Color(0xFF2D3748)),
                  em: GoogleFonts.sarabun(fontStyle: FontStyle.italic),
                  blockSpacing: 16.0,
                ),
              ),
            ),
            const SharedFooter(),
          ],
        ),
      ),
    );
  }
}
