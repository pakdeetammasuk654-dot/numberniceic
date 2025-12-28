import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sample_name.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/shared_footer.dart';
import '../widgets/upgrade_dialog.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'dashboard_page.dart';

class AnalyzerPage extends StatefulWidget {
  final String? initialName;
  final String? initialDay;

  const AnalyzerPage({super.key, this.initialName, this.initialDay});

  @override
  State<AnalyzerPage> createState() => _AnalyzerPageState();
}

class _AnalyzerPageState extends State<AnalyzerPage> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedDay = 'sunday';
  bool _isAuspicious = false;
  bool _disableKlakini = false;
  bool _isLoading = false;
  Map<String, dynamic>? _analysisResult;
  late AnimationController _rotationController;
  late AnimationController _rotationControllerOuter;
  late Future<bool> _isBuddhistDayFuture;
  late Future<Map<String, dynamic>> _userInfoFuture;
  late Future<List<SampleName>> _sampleNamesFuture;
  Timer? _debounce;
  bool _showScrollToTop = false;

  final List<Map<String, dynamic>> _days = [
    {'value': 'sunday', 'label': 'วันอาทิตย์', 'icon': Icons.wb_sunny, 'color': Colors.red},
    {'value': 'monday', 'label': 'วันจันทร์', 'icon': Icons.brightness_2, 'color': Color(0xFFFFD600)},
    {'value': 'tuesday', 'label': 'วันอังคาร', 'icon': Icons.bolt, 'color': Colors.pink},
    {'value': 'wednesday1', 'label': 'วันพุธ (กลางวัน)', 'icon': Icons.wb_cloudy, 'color': Colors.green},
    {'value': 'wednesday2', 'label': 'วันพุธ (กลางคืน)', 'icon': Icons.nightlight_round, 'color': Color(0xFF1B5E20)},
    {'value': 'thursday', 'label': 'วันพฤหัสบดี', 'icon': Icons.auto_stories, 'color': Colors.orange},
    {'value': 'friday', 'label': 'วันศุกร์', 'icon': Icons.favorite, 'color': Colors.blue},
    {'value': 'saturday', 'label': 'วันเสาร์', 'icon': Icons.filter_vintage, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    // Default name set to 'ปัญญา' like on the website if no name is provided
    _nameController.text = (widget.initialName != null && widget.initialName!.isNotEmpty) 
        ? widget.initialName! 
        : 'ปัญญา';
    
    // Normalize Day (Handle Thai names if passed)
    String rawDay = widget.initialDay ?? 'sunday';
    final dayMap = {
      'วันอาทิตย์': 'sunday',
      'วันจันทร์': 'monday',
      'วันอังคาร': 'tuesday',
      'วันพุธ': 'wednesday1',
      'วันพุธกลางวัน': 'wednesday1',
      'วันพุธ (กลางวัน)': 'wednesday1',
      'วันพุธกลางคืน': 'wednesday2',
      'วันพุธ (กลางคืน)': 'wednesday2',
      'วันพฤหัสบดี': 'thursday',
      'วันศุกร์': 'friday',
      'วันเสาร์': 'saturday',
    };
    
    _selectedDay = dayMap[rawDay] ?? rawDay.toLowerCase();
    
    // Safety check: ensure _selectedDay exists in _days list
    bool exists = _days.any((d) => d['value'] == _selectedDay);
    if (!exists) {
      _selectedDay = 'sunday';
    }

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Outer orbit radius is 140, Inner is 90.
    // To have same linear velocity, period T must be proportional to R.
    // T_outer = T_inner * (140 / 90) = 20 * 1.555... = ~31.11 seconds
    _rotationControllerOuter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 31111), 
    )..repeat();
    
    _isBuddhistDayFuture = ApiService.isBuddhistDayToday();
    _userInfoFuture = AuthService.getUserInfo();
    _sampleNamesFuture = ApiService.getSampleNames();

    // Always trigger analysis on start to show the Solar System initially
    _analyze();

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        bool show = _scrollController.offset > 400;
        if (show != _showScrollToTop) {
          setState(() {
            _showScrollToTop = show;
          });
        }
      }
    });
  }

  void _onInputChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _analyze();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rotationController.dispose();
    _rotationControllerOuter.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_nameController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.analyzeName(
        _nameController.text,
        _selectedDay,
        auspicious: _isAuspicious,
        disableKlakini: _disableKlakini,
      );
      setState(() {
        _analysisResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Future<void> _showLinguisticAnalysis() async {
    final name = _nameController.text;
    if (name.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 20),
            Material(
              color: Colors.transparent,
              child: Text(
                'โปรดรอสักครู่กำลังหารากศัพท์...',
                style: GoogleFonts.kanit(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await ApiService.analyzeLinguistically(name);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('ภาษาศาสตร์ของ $name', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: HtmlWidget(result['analysis'] ?? 'ไม่มีข้อมูล'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  Future<void> _saveCurrentName() async {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>;
    try {
      final msg = await ApiService.saveName(
        name: solar['cleaned_name'],
        day: solar['input_day_raw'],
        totalScore: solar['grand_total_score'],
        satSum: solar['total_numerology_value'],
        shaSum: solar['total_shadow_value'],
      );
      if (mounted) {
        _showStyledDialog(
          title: 'สำเร็จ',
          message: '$msg\nคุณสามารถดูรายชื่อที่บันทึกไว้ได้ที่เมนู Dashboard',
          icon: Icons.check_circle_outline,
          color: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        // Check if it's a login required error
        if (errorMsg.contains('เข้าสู่ระบบ')) {
          _showLoginRequiredDialog();
        } else {
          _showStyledDialog(
            title: 'แจ้งเตือน',
            message: errorMsg,
            icon: Icons.info_outline,
            color: Colors.orange,
          );
        }
      }
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.orange),
            const SizedBox(width: 10),
            Text('กรุณาเข้าสู่ระบบ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('กรุณาเข้าสู่ระบบก่อนบันทึกชื่อ', style: GoogleFonts.kanit()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegisterPage()),
              );
            },
            child: Text('ลงทะเบียน', style: GoogleFonts.kanit(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('เข้าสู่ระบบ', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStyledDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.kanit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ตกลง', style: GoogleFonts.kanit(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showUpgradeDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpgradeDialog(onSuccess: () {
        // Refresh analysis result to get VIP status
        _onInputChanged();
      }),
    );
  }

  void _showNumerologyDetail() {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>;
    final decodedParts = (solar['decoded_parts'] as List?) ?? [];
    final uniquePairs = (solar['all_unique_pairs'] as List?) ?? [];
    final name = solar['cleaned_name'];
    final isVip = _analysisResult!['is_vip'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('รายละเอียดเลขศาสตร์: $name', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ค่าพลังตัวอักษร', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
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
                const SizedBox(height: 24),
                Text('ทำนายเลขศาสตร์', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
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
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Text('🔒 เนื้อหานี้สำหรับสมาชิก VIP', 
                             style: GoogleFonts.kanit(fontSize: 13, color: Colors.amber[900], fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showUpgradeDialog();
                          },
                          child: Text('สมัครสมาชิก VIP เพื่ออ่านต่อ', 
                             style: GoogleFonts.kanit(color: Colors.blue[800], decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('วิเคราะห์ชื่อ', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const DashboardPage()),
                (route) => false,
              );
            },
            tooltip: 'ไปที่แดชบอร์ด',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF667EEA).withOpacity(0.05),
              const Color(0xFF764BA2).withOpacity(0.03),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildSearchForm(),
            
            // Reserve 2px height to prevent layout shift (jumping)
            SizedBox(
              height: 2,
              child: (_isLoading && _analysisResult != null)
                  ? const LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    )
                  : const SizedBox.shrink(),
            ),

            // Initial loading spinner
            if (_isLoading && _analysisResult == null)
              const Padding(
                padding: EdgeInsets.all(100),
                child: Center(child: CircularProgressIndicator(color: Colors.orange)),
              ),

            // Results Section (Visible when we have data)
            if (_analysisResult != null)
              Opacity(
                opacity: _isLoading ? 0.6 : 1.0, // Fade out slightly while loading
                child: Column(
                  children: [
                    _buildSampleNamesSection(),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Bottom layer: Analysis Header + Table (will be behind planets)
                        Column(
                          children: [
                            SizedBox(height: 330), // Space for solar system
                            _buildAnalysisHeader(),
                            if (_isLoading) _buildTableSkeleton() else _buildSimilarNamesTable(),
                          ],
                        ),
                        // Top layer: Solar System (will be on top of everything)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildSolarSystemSection(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SharedFooter(),
          ],
        ),
        ),
      ),
      floatingActionButton: _showScrollToTop 
         ? FloatingActionButton(
             onPressed: () {
               _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
             },
             backgroundColor: Colors.white,
             mini: true,
             elevation: 4,
             shape: const CircleBorder(),
             child: const Icon(Icons.arrow_upward, color: Colors.blueGrey),
           ) 
         : null,
    );
  }

  Widget _buildSearchForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            onChanged: (_) {
              setState(() {}); // Update clear button visibility
              _onInputChanged();
            },
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\u0E00-\u0E7F]')),
            ],
            decoration: InputDecoration(
              labelText: 'กรอกชื่อที่ต้องการวิเคราะห์',
              hintText: 'เช่น ปัญญา, สมชาย',
              helperText: 'วิเคราะห์อัตโนมัติเมื่อพิมพ์ชื่อ',
              helperStyle: GoogleFonts.kanit(color: Colors.blueAccent),
              prefixIcon: const Icon(Icons.person_outline),
              suffixIcon: _nameController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _nameController.clear();
                        });
                        _onInputChanged();
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedDay,
            decoration: InputDecoration(
              labelText: 'วันเกิด',
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: _days.map((day) {
              return DropdownMenuItem(
                value: day['value'] as String,
                child: Row(
                  children: [
                    Icon(day['icon'] as IconData, color: day['color'] as Color, size: 20),
                    const SizedBox(width: 10),
                    Text(day['label'] as String, style: GoogleFonts.kanit()),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedDay = val!);
              _onInputChanged();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            label: 'เลขศาสตร์',
            icon: Icons.assignment_outlined,
            color: Colors.blue,
            onTap: _showNumerologyDetail,
          ),
          _buildActionButton(
            label: 'ภาษาศาสตร์',
            icon: Icons.menu_book_outlined,
            color: Colors.green,
            onTap: _showLinguisticAnalysis,
          ),
          _buildActionButton(
            label: 'บันทึก',
            icon: Icons.save_outlined,
            color: Colors.orange,
            onTap: _saveCurrentName,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisHeader() {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>? ?? {};
    final name = solar['cleaned_name'] ?? '';
    final sunDisplayNameHTML = (solar['sun_display_name_html'] as List?) ?? [];
    final klakiniChars = (solar['klakini_chars'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final inputDay = solar['input_day_raw'] ?? '';

    return Transform.translate(
      offset: const Offset(0, -40),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0), // Removed bottom margin to touch next view
        child: CustomPaint(
          painter: SpeechBubblePainter(),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), // Extra bottom padding for tail
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Group Score Row
          
          // 1. Group Score Row (Replaced with Web Style)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               // Good/Bad Breakdown
               Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                       color: const Color(0xFF20BF6B).withOpacity(0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text(
                       'ดี +${(solar['num_positive_score'] as int? ?? 0) + (solar['sha_positive_score'] as int? ?? 0)}',
                       style: GoogleFonts.kanit(color: const Color(0xFF20BF6B), fontWeight: FontWeight.bold, fontSize: 13),
                     ),
                   ),
                   const SizedBox(height: 6),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                       color: const Color(0xFFEB4D4B).withOpacity(0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text(
                       'ร้าย ${(solar['num_negative_score'] as int? ?? 0) + (solar['sha_negative_score'] as int? ?? 0)}',
                       style: GoogleFonts.kanit(color: const Color(0xFFEB4D4B), fontWeight: FontWeight.bold, fontSize: 13),
                     ),
                   ),
                 ],
               ),
               const SizedBox(width: 24),
               // Total Score
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text('คะแนนรวม', style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600])),
                   Text(
                     '${(solar['grand_total_score'] ?? 0) > 0 ? '+' : ''}${solar['grand_total_score'] ?? 0}',
                     style: GoogleFonts.kanit(
                       fontSize: 32, 
                       height: 1,
                       fontWeight: FontWeight.bold, 
                       color: (solar['grand_total_score'] ?? 0) >= 0 ? const Color(0xFF26DE81) : const Color(0xFFEE5253),
                     ),
                   ),
                 ],
               ),
            ],
          ),
          const Divider(height: 32),

          // 2. Action Buttons Row (Horizontal)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildHeaderActionButtonHorizontal(
                  label: 'เลขศาสตร์',
                  icon: Icons.assignment_outlined,
                  color: Colors.blue,
                  onTap: _showNumerologyDetail,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeaderActionButtonHorizontal(
                  label: 'ภาษาศาสตร์',
                  icon: Icons.menu_book_outlined,
                  color: Colors.green,
                  onTap: _showLinguisticAnalysis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeaderActionButtonHorizontal(
                  label: 'บันทึก',
                  icon: Icons.save_outlined,
                  color: Colors.orange,
                  onTap: _saveCurrentName,
                ),
              ),
            ],
          ),
          const Divider(height: 32),

          // 3. Name and Toggles Row (Bottom)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: sunDisplayNameHTML.map((dc) {
                        return Text(
                          dc['char'] ?? '',
                          style: GoogleFonts.kanit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: dc['is_bad'] == true ? Colors.red : const Color(0xFF2D3748),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 12, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text(inputDay, style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildKlakiniBadge(klakiniChars),
                      ],
                    ),
                  ],
                ),
              ),
              // Toggles Card (Simplified version in the header)
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildToggleItemSmall(
                    labelWidget: Text('ชื่อดีเท่านั้น', style: GoogleFonts.kanit(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
                    value: _isAuspicious,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() => _isAuspicious = val);
                      _onInputChanged();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildToggleItemSmall(
                    labelWidget: RichText(
                      text: TextSpan(
                        style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600]),
                        children: [
                          const TextSpan(text: 'ปิด'),
                          TextSpan(text: 'ชื่อ', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                          const TextSpan(text: 'กาลกิณี'),
                        ],
                      ),
                    ),
                    value: _disableKlakini,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      setState(() => _disableKlakini = val);
                      _onInputChanged();
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
     ),
    ),
   ));
  }

  Widget _buildHeaderActionButtonHorizontal({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.kanit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKlakiniBadge(List<String> chars) {
    if (chars.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 12, color: Colors.green),
            const SizedBox(width: 4),
            Text('ไม่มีกาลกิณี', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning, size: 12, color: Colors.red),
          const SizedBox(width: 4),
          Text(chars.join(' '), style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildToggleItemSmall({
    String? label,
    Widget? labelWidget,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 24,
          width: 32,
          child: Transform.scale(
            scale: 0.75, // Slightly larger for better touch target
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: activeColor,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey[300],
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ),
        const SizedBox(height: 2),
        labelWidget != null
            ? labelWidget
            : Text(
                label ?? '',
                style: GoogleFonts.kanit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: value ? activeColor : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
      ],
    );
  }

  Widget _buildSampleNamesSection() {
    return FutureBuilder<List<SampleName>>(
      future: _sampleNamesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();

        final samples = snapshot.data!;

        return Stack(
          children: [
            Container(
              height: 90,
              padding: const EdgeInsets.only(top: 10),
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: samples.length,
                itemBuilder: (context, index) {
                  final sample = samples[index];
                  final isActive = _nameController.text.trim() == sample.name.trim();

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _nameController.text = sample.name;
                      });
                      _analyze();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                            color: isActive ? Colors.orange : Colors.grey[200]!,
                            width: 2,
                          ),
                          image: DecorationImage(
                            image: NetworkImage(
                              sample.avatarUrl.startsWith('http')
                                  ? sample.avatarUrl
                                  : '${ApiService.baseUrl}${sample.avatarUrl}',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sample.name,
                        style: GoogleFonts.kanit(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? Colors.orange : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
            // Right Fade Gradient to indicate scroll
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSolarSystemSection() {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>? ?? {};
    final name = solar['cleaned_name'] ?? '';
    final sunDisplayNameHTML = (solar['sun_display_name_html'] as List?) ?? [];
    final isSunDead = solar['is_sun_dead'] == true;

    return Transform.translate(
      offset: const Offset(0, -10),
      child: RepaintBoundary(
        child: Center(
            child: SizedBox(
              width: 320,
              height: 320,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                // Orbits (Static)
                CustomPaint(painter: OrbitPainter(), size: const Size(320, 320)),
                
                // Planets (Animated)
                // Use separate controllers to maintain equal linear velocity
                _buildPlanets((solar['shadow_pairs'] as List?) ?? [], 140, _rotationControllerOuter, false),
                _buildPlanets((solar['numerology_pairs'] as List?) ?? [], 90, _rotationController, false),

                // Sun (Static)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSunDead ? Colors.grey[600] : const Color(0xFFFFD700),
                    boxShadow: isSunDead ? [] : [
                      BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
                      BoxShadow(color: const Color(0xFFFFA500).withOpacity(0.3), blurRadius: 40, spreadRadius: 10),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: sunDisplayNameHTML.map((dc) {
                        return Text(
                          dc['char'] ?? '',
                          style: GoogleFonts.kanit(
                            fontSize: name.length > 5 ? 16 : 20,
                            fontWeight: FontWeight.bold,
                            color: dc['is_bad'] == true ? Colors.red : (isSunDead ? Colors.grey[300] : Colors.black87),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ),
    ));
  }

  Widget _buildPlanets(List pairs, double radius, AnimationController controller, bool reverse) {
    if (pairs.isEmpty) return const SizedBox();
    
    final angleStep = (2 * math.pi) / pairs.length;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final rotationValue = controller.value * 2 * math.pi * (reverse ? -1 : 1);
        
        return Stack(
          children: pairs.asMap().entries.map((entry) {
            final idx = entry.key;
            final pair = entry.value;
            final angle = rotationValue + (idx * angleStep);
            
            final color = _getPairColor(pair['meaning']?['pair_type'] ?? '');

            return Positioned(
              left: 160 + radius * math.cos(angle) - 18,
              top: 160 + radius * math.sin(angle) - 18,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
                ),
                child: Center(
                  child: Text(
                    pair['pair_number'] ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildScoreSummary() {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>? ?? {};
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildScoreColumn('เลขศาสตร์', solar['total_numerology_value'] ?? 0, solar['num_positive_score'] ?? 0, solar['num_negative_score'] ?? 0),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              _buildScoreColumn('พลังเงา', solar['total_shadow_value'] ?? 0, solar['sha_positive_score'] ?? 0, solar['sha_negative_score'] ?? 0),
            ],
          ),
          const Divider(height: 32),
          Text(
            'คะแนนรวมความแม่นยำ: ${solar['grand_total_score'] ?? 0}',
            style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D3748)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreColumn(String title, int total, int pos, int neg) {
    return Column(
      children: [
        Text(title, style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text('$total', style: GoogleFonts.kanit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF2D3748))),
        Row(
          children: [
            Text('+$pos', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('$neg', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  Widget _buildMeaningsSection() {
    final solar = _analysisResult!['solar_system'] as Map<String, dynamic>? ?? {};
    final uniquePairs = (solar['all_unique_pairs'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('คำทำนายภาพรวม', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...uniquePairs.map((p) => _buildMeaningItem(p)).toList(),
        ],
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
                Text(p['meaning']['miracle_desc'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(p['meaning']['miracle_detail'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarNamesTable() {
    final names = (_analysisResult!['similar_names'] as List?) ?? [];
    final isVip = _analysisResult!['is_vip'] == true;
    if (names.isEmpty) return const SizedBox();

    // VIP Banners
    Widget? vipBanner;
    if (!isVip) {
      vipBanner = Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFDB931)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
              child: const Icon(Icons.star, color: Color(0xFF4A3B00)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VIP ตั้งชื่อให้คมๆ', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF4A3B00))),
                  Text('วิเคราะห์คนจริง +3 แสนรายชื่อ', style: GoogleFonts.kanit(fontSize: 13, color: const Color(0xFF4A3B00))),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _showUpgradeDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('อัปเกรด', style: GoogleFonts.kanit()),
            ),
          ],
        ),
      );
    } else {
       vipBanner = Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Color(0xFF2C3E50)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                 gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFDB931)]),
                 shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user, color: Color(0xFF1A1A1A), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VIP Member Active', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700))),
                  Text('คุณกำลังใช้งานโหมดประสิทธิภาพสูงสุด', style: GoogleFonts.kanit(fontSize: 13, color: const Color(0xFFCCCCCC))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    List<TableRow> tableRows = [];

    // Table Header
    tableRows.add(
      TableRow(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 2)),
        ),
        children: [
          _buildTableHeaderCell('ชื่อดี', alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 16)),
          _buildTableHeaderCell('เลขศาสตร์'),
          _buildTableHeaderCell('พลังเงา'),
          _buildTableHeaderCell('คะแนน'),
          _buildTableHeaderCell('คล้าย'),
          _buildTableHeaderCell(''),
        ],
      ),
    );

    // Table Body & Lock Logic
    bool showLockMessage = false;
    int limit = isVip ? names.length : 3;

    for (int i = 0; i < names.length; i++) {
        if (i < limit) {
             tableRows.add(_buildNameTableRow(names[i]));
        } else {
            showLockMessage = true;
            break;
        }
    }

    return Transform.translate(
      offset: const Offset(0, -40),
      child: Container(
        color: Colors.white,
        child: Material(
            type: MaterialType.transparency,
            child: Column(
            children: [
              if (vipBanner != null) vipBanner,
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5), // Name
                  1: FlexColumnWidth(1.5),  // Sat
                  2: FlexColumnWidth(1.5),  // Sha
                  3: FlexColumnWidth(1.2),  // Score
                  4: FlexColumnWidth(1.2),  // Similarity
                  5: FixedColumnWidth(30),  // Icon
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: tableRows,
              ),
              
               if (!isVip && !showLockMessage && names.length <= 3)
                 Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDE7),
                      border: Border(
                         top: BorderSide(color: const Color(0xFFFBC02D).withOpacity(0.3)),
                      ),
                    ),
                    child: Column(
                      children: [
                         Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'แสดงผลลัพธ์จำกัด 3 รายชื่อ',
                              style: GoogleFonts.kanit(color: const Color(0xFFF57F17), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                         SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: _showUpgradeDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF57F17),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: Text('อัปเกรด VIP', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                 ),
              if (showLockMessage)
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDE7),
                    border: Border.all(color: const Color(0xFFFBC02D), style: BorderStyle.none),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock_outline, color: Color(0xFFF57F17), size: 28),
                      const SizedBox(height: 12),
                      Text(
                        'ชื่อดีถูกล็อกแสดงแค่ 3 รายชื่อเท่านั้น',
                        style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: const Color(0xFFF57F17)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _showUpgradeDialog,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          'สมัครสมาชิกเพื่อดูทั้งหมด',
                          style: GoogleFonts.kanit(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, {Alignment alignment = Alignment.center, EdgeInsets padding = EdgeInsets.zero}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12).add(padding),
      alignment: alignment,
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.kanit(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4A5568),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  TableRow _buildNameTableRow(Map n) {
    final isPremium = n['is_top_tier'] == true;
    final displayName = n['display_name_html'] as List;
    final similarity = (n['similarity'] as num? ?? 0) * 100;

    final onTap = () {
      _nameController.text = n['th_name'];
      _analyze();
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    };

    return TableRow(
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFFFFFDE7) : Colors.transparent,
        border: Border(
           bottom: BorderSide(color: isPremium ? const Color(0xFFFBC02D) : const Color(0xFFF0F4F8), width: isPremium ? 2 : 1),
        ),
      ),
      children: [
        // Name Cell
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    children: [
                      ...displayName.map((dc) => Text(
                        dc['char'] ?? '',
                        style: GoogleFonts.kanit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: dc['is_bad'] == true ? Colors.red : const Color(0xFF2D3748),
                        ),
                      )),
                      if (isPremium)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.star, color: Colors.orange, size: 14),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Sat Cell
        InkWell(
          onTap: onTap,
          child: Container(
             padding: const EdgeInsets.symmetric(vertical: 14),
             child: _buildPairBadgeRow(n['t_sat'] as List, n['sat_num'] as List)
          ),
        ),
        // Sha Cell
        InkWell(
          onTap: onTap,
          child: Container(
             padding: const EdgeInsets.symmetric(vertical: 14),
             child: _buildPairBadgeRow(n['t_sha'] as List, n['sha_num'] as List)
          ),
        ),
        // Score Cell
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (n['total_score'] ?? 0) >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(n['total_score'] ?? 0) > 0 ? '+' : ''}${n['total_score']}',
                style: GoogleFonts.kanit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: (n['total_score'] ?? 0) >= 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ),
        ),
        // Similarity Cell
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              '${similarity.toStringAsFixed(0)}%',
              style: GoogleFonts.kanit(fontSize: 12, color: const Color(0xFFADB5BD)),
            ),
          ),
        ),
        // Icon Cell
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Icon(Icons.search, size: 16, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  Widget _buildPairBadgeRow(List pairs, List nums) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        children: pairs.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          return Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _getPairColor(p['type'])),
            child: Center(
              child: Text(
                '${nums[idx]}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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

  Widget _buildTableSkeleton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(5, (index) => 
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 100, 
                  height: 20, 
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 20, 
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))
                  )
                ),
              ],
            ),
          )
        ),
      ),
    );
  }
}

class OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 5, dashSpace = 5;
    final center = Offset(size.width / 2, size.height / 2);

    void drawDashedCircle(double radius) {
      final circumference = 2 * math.pi * radius;
      final totalSteps = (circumference / (dashWidth + dashSpace)).floor();
      for (int i = 0; i < totalSteps; i++) {
        final startAngle = (i * (dashWidth + dashSpace) / radius);
        final sweepAngle = dashWidth / radius;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
      }
    }

    drawDashedCircle(90);
    drawDashedCircle(140);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SpeechBubblePainter extends CustomPainter {
  final Color color;
  final Color shadowColor;

  SpeechBubblePainter({this.color = Colors.white, this.shadowColor = const Color(0x0D000000)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final path = Path();
    const radius = 20.0;
    const tailWidth = 24.0;
    const tailHeight = 12.0;

    // Main Box (adjusted height to leave space for tail)
    final boxRect = RRect.fromLTRBAndCorners(
      0, 0, size.width, size.height - tailHeight,
      topLeft: const Radius.circular(radius),
      topRight: const Radius.circular(radius),
      bottomLeft: const Radius.circular(radius),
      bottomRight: const Radius.circular(radius),
    );
    
    path.addRRect(boxRect);

    // Tail (Bottom Center)
    path.moveTo(size.width / 2 - tailWidth / 2, size.height - tailHeight);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 + tailWidth / 2, size.height - tailHeight);
    path.close();

    // Draw Shadow
    canvas.drawPath(path, shadowPaint);
    
    // Draw Background
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
