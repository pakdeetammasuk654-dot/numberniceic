import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/custom_toast.dart';
import '../widgets/upgrade_dialog.dart';
import 'landing_page.dart';
import 'analyzer_page.dart';
import 'articles_page.dart';
import 'login_page.dart';
import 'main_tab_page.dart';
import 'shop_page.dart';
import 'shipping_address_page.dart';
import 'order_history_page.dart';
import 'privacy_policy_page.dart';
import 'delete_account_page.dart';
import '../widgets/shared_footer.dart';
import '../widgets/lucky_number_card.dart'; // Import for Saved Number Display

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
    // Listen for refresh signals from other pages (e.g. AnalyzerPage after saving)
    ApiService.dashboardRefreshSignal.addListener(_loadDashboard);
  }

  @override
  void dispose() {
    ApiService.dashboardRefreshSignal.removeListener(_loadDashboard);
    super.dispose();
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

  Future<void> _showUpgradeDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpgradeDialog(onSuccess: () {
        _loadDashboard();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Cleaner off-white background
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadDashboard(),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                // ... Error Handling (Same as before)
                if (snapshot.error.toString().contains('Session expired') || 
                    snapshot.error.toString().contains('User no longer exists')) {
                   WidgetsBinding.instance.addPostFrameCallback((_) {
                    CustomToast.show(context, 'เซสชั่นหมดอายุ กรุณาเข้าสู่ระบบใหม่', isSuccess: false);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const MainTabPage(initialIndex: 0)),
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
              final isVip = data['is_vip'] == true || data['IsVIP'] == true;
              final statusVal = data['status'] ?? data['Status'] ?? 0;
              final statusInt = statusVal is int ? statusVal : (statusVal is num ? statusVal.toInt() : 0);
              final isAdmin = statusInt == 9;
              final savedNames = (data['saved_names'] ?? data['SavedNames']) as List<dynamic>? ?? [];
              
              final username = data['username'] ?? data['Username'] ?? 'User';
              final email = data['email'] ?? data['Email'] ?? '';
              final avatarUrl = data['avatar_url'] ?? data['AvatarURL'];
              final tel = data['tel'] ?? data['Tel'] ?? '';
              final hasAddress = data['has_shipping_address'] == true || data['HasShippingAddress'] == true;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 1. Premium Header with Avatar
                    _buildPremiumHeader(context, username, email, avatarUrl, isVip, isAdmin),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20), // More breathing room
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          
                          // 2. VIP Privilege Card
                          _buildPrivilegeCard(isVip),
                          
                          const SizedBox(height: 24),
                          
                          // 3. Saved Names Section
                          _buildSavedNamesHeader(savedNames.length),
                          const SizedBox(height: 12),
                          if (savedNames.isEmpty)
                            _buildEmptyState()
                          else
                            _buildSavedNamesTable(savedNames, isVip),
                            
                          const SizedBox(height: 32),
                          
                          // 4. Menu Section (Clean List)
                          Text('เมนูบัญชีผู้ใช้', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 12),
                          _buildMenuCard(context, hasAddress),

                          const SizedBox(height: 32),

                          // 5. Logout Button (Distinct & Bottom)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await AuthService.logout();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => const MainTabPage(initialIndex: 0)),
                                    (route) => false,
                                  );
                                  CustomToast.show(context, 'ออกจากระบบเรียบร้อยแล้ว');
                                }
                              },
                              icon: const Icon(Icons.logout, color: Colors.redAccent),
                              label: Text('ออกจากระบบ', style: GoogleFonts.kanit(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: Colors.red.withOpacity(0.02),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 48),
                          const SharedFooter(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- New Header Widget ---
  Widget _buildPremiumHeader(BuildContext context, String username, String email, String? avatarUrl, bool isVip, bool isAdmin) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
           // Avatar with Glow
           Stack(
             alignment: Alignment.center,
             children: [
               if (isVip)
                 Container(
                   width: 108, 
                   height: 108,
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                     boxShadow: [
                        BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 20, spreadRadius: 2)
                     ],
                   ),
                 ),
               Container(
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   border: Border.all(color: Colors.white, width: 4),
                 ),
                 child: CircleAvatar(
                   radius: 50,
                   backgroundColor: Colors.grey[100],
                   backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
                      ? NetworkImage(avatarUrl) 
                      : null,
                   child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: GoogleFonts.kanit(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.grey[400]),
                        )
                      : null,
                 ),
               ),
               if (isAdmin)
                 Positioned(
                   bottom: 0,
                   right: 0,
                   child: Container(
                     padding: const EdgeInsets.all(6),
                     decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                     child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                   ),
                 )
             ],
           ),
           const SizedBox(height: 16),
           
           // Username
           Text(
             username, 
             style: GoogleFonts.kanit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)
           ),
           
           // VIP Badge / Email
           const SizedBox(height: 4),
           Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               if (isVip)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFDB931)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text('VIP MEMBER', style: GoogleFonts.kanit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
               Text(email, style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[500])),
             ],
           ),
        ],
      ),
    );
  }

  // --- Modified Saved Names Header ---
  Widget _buildSavedNamesHeader(int count) {
     return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.2), 
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: const Icon(Icons.bookmark_border_rounded, color: Color(0xFFB78900), size: 20),
                ),
                const SizedBox(width: 12),
                Text('รายชื่อที่บันทึก', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count / 12 รายชื่อ',
                style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
              ),
            ),
        ],
     );
  }

  // --- New Menu Card Widget ---
  Widget _buildMenuCard(BuildContext context, bool hasAddress) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
           _buildMenuItem(
             context,
             icon: Icons.history,
             title: 'ประวัติการสั่งซื้อ',
             iconColor: Colors.blueAccent,
             onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryPage())),
           ),
           const Divider(height: 1, indent: 60),
           _buildMenuItem(
             context,
             icon: Icons.location_on_outlined,
             title: 'จัดการที่อยู่จัดส่ง',
             iconColor: hasAddress ? Colors.green : Colors.orange,
             subtitle: hasAddress ? null : 'ยังไม่ได้เพิ่มที่อยู่',
             onTap: () async {
                 await Navigator.push(context, MaterialPageRoute(builder: (context) => const ShippingAddressPage()));
                 _loadDashboard();
             },
           ),
           const Divider(height: 1, indent: 60),
           _buildMenuItem(
              context,
              icon: Icons.lock_outline,
              title: 'นโยบายความเป็นส่วนตัว',
              iconColor: Colors.grey[600]!,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()))
           ),
           const Divider(height: 1, indent: 60),
            _buildMenuItem(
              context,
              icon: Icons.delete_outline,
              title: 'ขอลบบัญชีผู้ใช้',
              iconColor: Colors.grey[400]!,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DeleteAccountPage()))
           ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {
    required IconData icon,
    required String title,
    required Color iconColor,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.kanit(fontSize: 12, color: Colors.orange)) : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildPrivilegeCard(bool isVip) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVip 
            ? [const Color(0xFF480048), const Color(0xFFC04848)] // Majestic Imperial Purple to Deep Red hint for VIP
            : [const Color(0xFF2D0133), const Color(0xFF5D0E7D)], // Deep Royal Purple for Normal
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF6A0DAD).withOpacity(0.3), // Royal Purple Glow
            blurRadius: 40,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isVip ? const Color(0xFFEAD4AA) : Colors.blue).withOpacity(0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 1.5),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVip ? 'สมาชิกระดับ VIP' : 'สมาชิกระดับทั่วไป',
                              style: GoogleFonts.kanit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFD700), // Back to Vibrant Gold
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isVip)
                              Text(
                                'PREMIUM ACCESS UNLOCKED',
                                style: GoogleFonts.kanit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withOpacity(0.5),
                                  letterSpacing: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isVip 
                      ? 'คุณได้รับสิทธิประโยชน์ขั้นสูงสุดในการใช้งานระบบแล้ว'
                      : 'อัปเกรดเป็น VIP เพื่อเข้าถึงข้อมูลเชิงลึกและรายชื่อค้นหาพิเศษกว่า 300,000 รายชื่อ',
                    style: GoogleFonts.kanit(
                      fontSize: 15, 
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPrivilegeItem('วิเคราะห์ความหมายคู่เลขไม่จำกัด'),
                  _buildPrivilegeItem('เข้าถึงฐานข้อมูล 300,000+ ชื่อ'),
                  _buildPrivilegeItem('วิเคราะห์ตามตำราโบราณครบทุกชั้น'),
                  if (!isVip) ...[
                    const SizedBox(height: 30),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.confirmation_number_outlined, color: Colors.blueAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'มีรหัสโปรโมชันหรือรหัส VIP?', 
                                    style: GoogleFonts.kanit(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'สามารถนำรหัสที่ได้จากกิจกรรมหรือการสั่งซื้อสินค้า มากรอกเพื่อรับสิทธิ์ได้ทันที', 
                                style: GoogleFonts.kanit(fontSize: 12, color: Colors.white60, height: 1.4),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFFD700).withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _showRedeemDialog,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFFD700),
                                          foregroundColor: const Color(0xFF0F172A),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.vpn_key_outlined, size: 18),
                                            const SizedBox(width: 8),
                                            Text('กรอกรหัส VIP', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _goToShop,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.shopping_bag_outlined, size: 18),
                                          const SizedBox(width: 8),
                                          Text('ซื้อสินค้าร้านมาดี', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToShop() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShopPage()),
    );
  }

  void _showRedeemDialog() {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('กรอกรหัส VIP', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('นำรหัสที่ได้รับจากสินค้ามงคลหรือกิจกรรมมากรอกที่นี่', style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                hintText: 'เช่น AB12CD34',
                hintStyle: GoogleFonts.kanit(color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.kanit(letterSpacing: 1.5, fontWeight: FontWeight.bold),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              
              Navigator.pop(context); // Close dialog
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final msg = await ApiService.redeemCode(code);
                if (context.mounted) {
                  Navigator.pop(context); // Remove loading
                  
                  // Success Dialog
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('สำเร็จ!', style: GoogleFonts.kanit(fontWeight: FontWeight.bold))
                      ]),
                      content: Text(msg, style: GoogleFonts.kanit()),
                      actions: [
                        TextButton(
                           onPressed: () { 
                             Navigator.pop(ctx);
                             _loadDashboard(); // Refresh dashboard
                           },
                           child: Text('ตกลง', style: GoogleFonts.kanit()),
                        )
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Remove loading
                   // Error Dialog
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('ไม่สำเร็จ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.red)),
                      content: Text(e.toString().replaceAll('Exception: ', ''), style: GoogleFonts.kanit()),
                      actions: [
                        TextButton(
                           onPressed: () => Navigator.pop(ctx),
                           child: Text('ตกลง', style: GoogleFonts.kanit()),
                        )
                      ],
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
               backgroundColor: const Color(0xFF28a745),
               foregroundColor: Colors.white,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('ใช้งานรหัส', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  Widget _buildPrivilegeItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFFFFD700),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFF0F172A), size: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.kanit(
                fontSize: 14, 
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String username, String email, String tel, String? avatarUrl, bool isVip, bool isAdmin, bool hasShippingAddress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              avatarUrl != null && avatarUrl.isNotEmpty
                ? CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.transparent,
                    backgroundImage: NetworkImage(avatarUrl),
                  )
                : CircleAvatar(
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
                    if (tel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.phone_android_rounded, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(tel, style: GoogleFonts.kanit(fontSize: 13, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          InkWell(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryPage()));
            },
            child: Row(
              children: [
                const Icon(Icons.history, size: 18, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text('ประวัติการสั่งซื้อ', 
                  style: GoogleFonts.kanit(
                    fontSize: 14, 
                    color: Colors.blueAccent, 
                    fontWeight: FontWeight.w500
                  )
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
          const Divider(height: 16),
          InkWell(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const ShippingAddressPage()));
              _loadDashboard();
            },
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: hasShippingAddress ? Colors.blueAccent : Colors.orange[700]),
                const SizedBox(width: 8),
                Text('จัดการที่อยู่จัดส่ง', 
                  style: GoogleFonts.kanit(
                    fontSize: 14, 
                    color: hasShippingAddress ? Colors.blueAccent : Colors.orange[700], 
                    fontWeight: FontWeight.w500
                  )
                ),
                if (!hasShippingAddress) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.error_outline, size: 14, color: Colors.orange[700]),
                ],
                const Spacer(),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
          const Divider(height: 16),
          InkWell(
            onTap: () async {
                 await AuthService.logout();
                 if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const MainTabPage(initialIndex: 0)),
                      (route) => false,
                    );
                    CustomToast.show(context, 'ออกจากระบบเรียบร้อยแล้ว');
                 }
            },
            child: Row(
              children: [
                const Icon(Icons.logout, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('ออกจากระบบ', 
                  style: GoogleFonts.kanit(
                    fontSize: 14, 
                    color: Colors.grey[600], 
                    fontWeight: FontWeight.w500
                  )
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ],
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
                Expanded(flex: 3, child: Text('ชื่อ/สกุล', style: GoogleFonts.kanit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
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
            
            // ----------------------------------------------------
            // Check if this saved item is a PHONE NUMBER (for Gold Card display)
            // ----------------------------------------------------
            final isPhone = name.length == 10 && int.tryParse(name) != null;

            if (isPhone) {
                // Calculate Sum
                int sum = 0;
                try {
                  sum = name.split('').fold(0, (p, c) => p + int.parse(c));
                } catch (_) {}
                
                // Keywords: For saved items, maybe we don't have analysis breakdown unless we fetch it.
                // But the image shows "Health, Safety, Stability". 
                // We'll use a placeholder or derived if available in saved data?
                // Saved data structure might not hold keywords.
                // We will use Meaning if available or generic.
                List<String> keywords = [ 'ความมั่งคั่ง', 'บารมี', 'โชคลาภ' ]; // Default positive keywords
                if (nameData['meaning'] != null) keywords = [ nameData['meaning'].toString() ];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  child: LuckyNumberCard(
                    phoneNumber: name,
                    sum: sum,
                    isVip: true, // Show VIP badge as per image
                    keywords: keywords,
                    buyButtonLabel: 'ซื้อเบอร์',
                    // secondary button: Analyze (Navigate to details)
                    analyzeButtonLabel: 'วิเคราะห์',
                    analyzeButtonColor: const Color(0xFF2962FF),
                    analyzeButtonBorderColor: const Color(0xFFBBDEFB),
                    onBuy: () {
                       Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopPage()));
                    },
                    onAnalyze: () async {
                       await Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyzerPage(initialName: name, initialDay: birthDayRaw)));
                       _loadDashboard();
                    },
                    onClose: () => _confirmDelete(id), // Delete via X button
                  ),
                );
            }

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
                          Row(
                            children: [
                               Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  '#${index + 1}',
                                  style: GoogleFonts.kanit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: displayNameHtml.isEmpty
                                  ? Text(
                                      name,
                                      style: GoogleFonts.kanit(
                                        fontSize: 14,
                                        fontWeight: isTopTier ? FontWeight.w800 : FontWeight.bold,
                                        color: isTopTier ? const Color(0xFFB8860B) : Colors.black87,
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Flexible(
                                          child: Wrap(
                                            children: displayNameHtml.map((charData) {
                                              final char = charData['char'] ?? charData['Char'] ?? '';
                                              final isBad = charData['is_bad'] == true || charData['IsBad'] == true;
                                              return Text(
                                                char,
                                                style: GoogleFonts.kanit(
                                                  fontSize: 14,
                                                  fontWeight: isTopTier ? FontWeight.w800 : FontWeight.bold,
                                                  color: isBad ? const Color(0xFFFF4757) : (isTopTier ? const Color(0xFFB8860B) : Colors.black87),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        if (isTopTier)
                                          const Text(' ⭐', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 10, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                birthDayThai,
                                style: GoogleFonts.kanit(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
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



