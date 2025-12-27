import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/custom_toast.dart';
import 'landing_page.dart';
import 'analyzer_page.dart';
import 'articles_page.dart';
import 'login_page.dart';
import '../widgets/shared_footer.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _dashboardFuture;
  late Future<bool> _isBuddhistDayFuture;
  late Future<Map<String, dynamic>> _userInfoFuture;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _isBuddhistDayFuture = ApiService.isBuddhistDayToday();
    _userInfoFuture = AuthService.getUserInfo();
  }

  void _loadDashboard() {
    setState(() {
      _dashboardFuture = ApiService.getDashboard();
    });
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: Text('คุณต้องการลบรายชื่อนี้ใช่หรือไม่?', style: GoogleFonts.kanit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('ลบ', style: GoogleFonts.kanit(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final msg = await ApiService.deleteSavedName(id);
        CustomToast.show(context, msg);
        _loadDashboard();
      } catch (e) {
        CustomToast.show(context, e.toString().replaceAll('Exception: ', ''), isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('แดชบอร์ด', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF333333),
        elevation: 0,
        scrolledUnderElevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF444444),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Buddhist Day Badge
                FutureBuilder<bool>(
                  future: _isBuddhistDayFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data == true) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_vintage_rounded, size: 18, color: Color(0xFFFFD700)),
                            const SizedBox(width: 6),
                            Text(
                              'วันนี้วันพระ', 
                              style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700)),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
                
                // Green Action Button
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const AnalyzerPage()),
                    );
                    _loadDashboard();
                  },
                  icon: const Icon(Icons.analytics_rounded, size: 16),
                  label: Text('วิเคราะห์ชื่อ', style: GoogleFonts.kanit(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF28a745),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LandingPage()),
              (route) => false,
            ),
            tooltip: 'กลับหน้าหลัก',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _userInfoFuture,
          builder: (context, snapshot) {
             final userInfo = snapshot.data;
             final isLoggedIn = userInfo != null && userInfo['username'] != null;
             
             return ListView(
               padding: EdgeInsets.zero,
               children: [
                 DrawerHeader(
                   decoration: const BoxDecoration(
                     gradient: LinearGradient(
                       colors: [Color(0xFF00b09b), Color(0xFF96c93d)],
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight,
                     ),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                       const CircleAvatar(
                         radius: 30,
                         backgroundColor: Colors.white,
                         child: Icon(Icons.person, size: 40, color: Colors.teal),
                       ),
                       const SizedBox(height: 10),
                       Text(
                         isLoggedIn ? 'สวัสดี, ${userInfo['username']}' : 'ยินดีต้อนรับ',
                         style: GoogleFonts.kanit(
                           color: Colors.white,
                           fontSize: 20,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ],
                   ),
                 ),
                 
                 ListTile(
                   leading: const Icon(Icons.home),
                   title: Text('หน้าแรก', style: GoogleFonts.kanit()),
                   onTap: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LandingPage()),
                      (route) => false,
                   ),
                 ),
                 ListTile(
                   leading: const Icon(Icons.article),
                   title: Text('บทความ', style: GoogleFonts.kanit()),
                   onTap: () {
                     Navigator.pop(context);
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (context) => const ArticlesPage()),
                     );
                   },
                 ),
                 const Divider(),

                 // Dashboard is already here, no need link
                 
                 ListTile(
                   leading: const Icon(Icons.logout, color: Colors.deepOrange),
                   title: Text('ออกจากระบบ', style: GoogleFonts.kanit(color: Colors.deepOrange)),
                   onTap: () async {
                     await AuthService.logout();
                     if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LandingPage()),
                          (route) => false,
                        );
                        CustomToast.show(context, 'ออกจากระบบเรียบร้อยแล้ว');
                     }
                   },
                 ),
               ],
             );
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadDashboard(),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              // Handle Session Expired
              if (snapshot.error.toString().contains('Session expired')) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  CustomToast.show(context, 'เซสชั่นหมดอายุ กรุณาเข้าสู่ระบบใหม่', isSuccess: false);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LandingPage()),
                    (route) => false,
                  );
                });
                return const SizedBox();
              }
              return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.kanit()));
            } else if (!snapshot.hasData) {
              return const Center(child: Text('ไม่มีข้อมูล', style: TextStyle(fontFamily: 'Kanit')));
            }

            final data = snapshot.data!;
            // Log full data for debugging to console
            debugPrint('DASHBOARD_DATA: $data');

            // Handle both snake_case and PascalCase from Go
            final isVip = data['is_vip'] == true || data['IsVIP'] == true;
            final statusVal = data['status'] ?? data['Status'] ?? 0;
            final statusInt = statusVal is int ? statusVal : (statusVal is num ? statusVal.toInt() : 0);
            final isAdmin = statusInt == 9;

            final savedNames = (data['saved_names'] ?? data['SavedNames']) as List<dynamic>? ?? [];
            final assignedColorsRaw = data['assigned_colors'] ?? data['AssignedColors'] ?? [];
            final assignedColors = List<String>.from(assignedColorsRaw);

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // 1. User Profile Card
                  _buildProfileCard(
                    data['username'] ?? data['Username'] ?? '', 
                    data['email'] ?? data['Email'] ?? '', 
                    isVip, 
                    isAdmin
                  ),
                  
                  const SizedBox(height: 16),

                  // 1.5 Privilege Card (Matching Web UI)
                  _buildPrivilegeCard(isVip),

                  const SizedBox(height: 24),

                  // 2. VIP Section (Wallet Colors)
                  // Show section if VIP, even if colors are loading/empty (to debug)
                  if (isVip) ...[
                    Text('สีกระเป๋ามงคลของคุณ', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (assignedColors.isNotEmpty && assignedColors.any((c) => c.isNotEmpty))
                       _buildWalletColors(assignedColors)
                    else
                       Container(
                         padding: const EdgeInsets.all(20),
                         width: double.infinity,
                         decoration: BoxDecoration(
                           color: Colors.amber[50], 
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(color: Colors.amber.shade200)
                         ),
                         child: Column(
                           children: [
                             const Icon(Icons.wallet, color: Colors.amber, size: 48),
                             const SizedBox(height: 12),
                             Text('ไม่พบข้อมูลสีกระเป๋า', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber[900])),
                             const SizedBox(height: 4),
                             Text('อัปเดตข้อมูลวันเกิดในโปรไฟล์เพื่อรับสีกระเป๋า', style: GoogleFonts.kanit(fontSize: 13, color: Colors.amber[800])),
                           ],
                         ),
                       ),
                    const SizedBox(height: 24),
                  ] else ...[
                     const SizedBox(height: 24),
                  ],

                  // 3. Saved Names Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('รายชื่อที่บันทึกไว้', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300)
                        ),
                        child: Text(
                          '${savedNames.length} / 12 รายชื่อ',
                          style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (savedNames.isEmpty)
                    _buildEmptyState()
                  else
                    _buildSavedNamesTable(savedNames, isVip),
                      ],
                    ),
                  ),
                  // Footer - full width outside padding
                  const SizedBox(height: 30),
                  const SharedFooter(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPrivilegeCard(bool isVip) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Color(0xFFFFD700), size: 24),
              const SizedBox(width: 8),
              Text(
                isVip ? 'สมาชิกระดับ VIP' : 'สมาชิกระดับทั่วไป',
                style: GoogleFonts.kanit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isVip 
              ? 'คุณได้รับสิทธิประโยชน์ขั้นสูงสุดในการใช้งานระบบแล้ว'
              : 'อัปเกรดเป็น VIP เพื่อเข้าถึงข้อมูลเชิงลึกและรายชื่อค้นหาพิเศษกว่า 300,000 รายชื่อ',
            style: GoogleFonts.kanit(fontSize: 14, color: Colors.blueGrey[100]),
          ),
          const SizedBox(height: 16),
          _buildPrivilegeItem('วิเคราะห์ความหมายคู่เลขไม่จำกัด'),
          _buildPrivilegeItem('เข้าถึงฐานข้อมูล 300,000+ ชื่อ'),
          _buildPrivilegeItem('วิเคราะห์ตามตำราโบราณครบทุกชั้น'),
          if (!isVip) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                   CustomToast.show(context, 'กรุณาอัปเกรดผ่านทางหน้าเว็บไซต์หลัก');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF4A3B00),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: Text('อัปเกรดเป็น VIP ทันที', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivilegeItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.kanit(fontSize: 13, color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String username, String email, bool isVip, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isVip ? Colors.amber[100] : Colors.teal[50],
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: GoogleFonts.kanit(fontSize: 24, fontWeight: FontWeight.bold, color: isVip ? Colors.amber[800] : Colors.teal),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(username, style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold)),
                    if (isVip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('VIP', style: GoogleFonts.kanit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber[800])),
                      )
                    ],
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('ADMIN', style: GoogleFonts.kanit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red[800])),
                      )
                    ]
                  ],
                ),
                Text(email, style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletColors(List<String> colors) {
    // Map color names to Color objects (Simplified mapping for demo)
    Color getColor(String colorStr) {
      colorStr = colorStr.toLowerCase().trim();
      
      // Handle Hex strings like #FFFFFF
      if (colorStr.startsWith('#')) {
        try {
          String hex = colorStr.replaceAll('#', '');
          if (hex.length == 6) hex = 'FF' + hex; // Add alpha if missing
          return Color(int.parse(hex, radix: 16));
        } catch (e) {
          return Colors.grey.shade300;
        }
      }

      // Fallback to Thai name mapping
      if (colorStr.contains('แดง')) return Colors.red;
      if (colorStr.contains('เหลือง')) return Colors.yellow;
      if (colorStr.contains('ชมพู')) return Colors.pinkAccent;
      if (colorStr.contains('เขียว')) return Colors.green;
      if (colorStr.contains('ส้ม') || colorStr.contains('แสด')) return Colors.orange;
      if (colorStr.contains('ฟ้า') || colorStr.contains('น้ำเงิน')) return Colors.blue;
      if (colorStr.contains('ม่วง')) return Colors.purple;
      if (colorStr.contains('ดำ')) return Colors.black;
      if (colorStr.contains('ขาว')) return Colors.white;
      if (colorStr.contains('เทา')) return Colors.grey;
      return Colors.grey.shade300;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
        boxShadow: [
           BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: colors.map((c) {
          final isHex = c.startsWith('#');
          return Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: getColor(c),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black.withOpacity(0.1), offset: const Offset(0, 2))]
                ),
              ),
              const SizedBox(height: 8),
              if (!isHex)
                 Text(c, style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w500))
              else
                 const SizedBox(height: 12), // Spacer if no text
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSavedNamesTable(List<dynamic> savedNames, bool isUserVip) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('ชื่อ/วันเกิด', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
                Expanded(flex: 2, child: Center(child: Text('เลข', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)))),
                Expanded(flex: 2, child: Center(child: Text('เงา', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)))),
                Expanded(flex: 1, child: Center(child: Text('คะแนน', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)))),
                const SizedBox(width: 40), // Space for delete icon
              ],
            ),
          ),
          // Table Body
          ...savedNames.asMap().entries.map((entry) {
            final index = entry.key;
            final nameData = entry.value;
            final isLast = index == savedNames.length - 1;
            
            final name = nameData['name'] ?? nameData['Name'] ?? 'ไม่ทราบชื่อ';
            final birthDayThai = nameData['birth_day_thai'] ?? nameData['BirthDayThai'] ?? '';
            final totalScore = nameData['total_score'] ?? nameData['TotalScore'] ?? 0;
            final isTopTier = nameData['is_top_tier'] == true || nameData['IsTopTier'] == true;
            final birthDayRaw = nameData['birth_day_raw'] ?? nameData['BirthDayRaw'] ?? 'sunday';
            final displayNameHtml = (nameData['display_name_html'] ?? nameData['DisplayNameHTML'] ?? []) as List<dynamic>;
            final satPairs = (nameData['sat_pairs'] ?? nameData['SatPairs'] ?? []) as List<dynamic>;
            final shaPairs = (nameData['sha_pairs'] ?? nameData['ShaPairs'] ?? []) as List<dynamic>;
            final id = nameData['id'] ?? nameData['ID'] ?? 0;

            return InkWell(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyzerPage(initialName: name, initialDay: birthDayRaw)));
                _loadDashboard();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isTopTier ? const Color(0xFFFFFDE7) : (index % 2 == 0 ? Colors.white : Colors.grey[50]),
                  border: Border(
                    bottom: isLast ? BorderSide.none : BorderSide(color: Colors.grey.shade100),
                    left: isTopTier ? const BorderSide(color: Color(0xFFFBC02D), width: 3) : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    // Column 1: Name & Birthday
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          displayNameHtml.isEmpty
                              ? Text(
                                  name,
                                  style: GoogleFonts.kanit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                )
                              : Wrap(
                                  children: displayNameHtml.map((charData) {
                                    final char = charData['char'] ?? charData['Char'] ?? '';
                                    final isBad = charData['is_bad'] == true || charData['IsBad'] == true;
                                    return Text(
                                      char,
                                      style: GoogleFonts.kanit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isBad ? const Color(0xFFFF4757) : Colors.black87,
                                      ),
                                    );
                                  }).toList(),
                                ),
                          Text(
                            'วัน$birthDayThai',
                            style: GoogleFonts.kanit(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    // Column 2: Sat Pairs
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          alignment: WrapAlignment.center,
                          children: satPairs.take(2).map((p) => _buildMiniPairCircle(p)).toList(),
                        ),
                      ),
                    ),
                    // Column 3: Sha Pairs
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          alignment: WrapAlignment.center,
                          children: shaPairs.take(2).map((p) => _buildMiniPairCircle(p)).toList(),
                        ),
                      ),
                    ),
                    // Column 4: Score
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isTopTier)
                            const Text('⭐', style: TextStyle(fontSize: 10)),
                          Text(
                            '${totalScore > 0 ? "+" : ""}$totalScore',
                            style: GoogleFonts.kanit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: totalScore >= 0 ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Column 5: Delete
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 20),
                        onPressed: () => _confirmDelete(id),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMiniPairCircle(dynamic p) {
    final num = p['number'] ?? p['Number'] ?? '??';
    final colorStr = p['color'] ?? p['Color'] ?? '#CCCCCC';
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _parseHexColor(colorStr),
        shape: BoxShape.circle,
      ),
      child: Text(
        num,
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPairRow(String label, List<dynamic> pairs) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.kanit(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: pairs.map((p) {
              final num = p['Number'] ?? '??';
              final colorStr = p['Color'] ?? '#CCCCCC';
              return Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _parseHexColor(colorStr),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                  boxShadow: [BoxShadow(blurRadius: 2, color: Colors.black.withOpacity(0.1))],
                ),
                child: Text(
                  num,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _parseHexColor(String hex) {
    try {
      String cleanHex = hex.replaceAll('#', '');
      if (cleanHex.length == 6) cleanHex = 'FF' + cleanHex;
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.bookmark_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('ยังไม่มีรายชื่อที่บันทึก', style: GoogleFonts.kanit(color: Colors.grey)),
        ],
      ),
    );
  }
  

}

