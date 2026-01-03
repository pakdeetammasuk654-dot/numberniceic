import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
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
              padding: const EdgeInsets.all(16),
              child: HtmlWidget(
                analysisHtml,
                textStyle: GoogleFonts.kanit(),
              ),
            ),
            const SharedFooter(),
          ],
        ),
      ),
    );
  }
}
