import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'notification_list_page.dart';
import 'order_history_page.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';
import 'privacy_policy_page.dart';
import 'delete_account_page.dart';
import '../widgets/shared_footer.dart';
import '../widgets/adaptive_footer_scroll_view.dart';
import '../widgets/lucky_number_card.dart'; // Import for Saved Number Display
import '../widgets/wallet_color_bottom_sheet.dart'; 
import '../widgets/notification_bell.dart'; // NEW Reusable Bell

import '../services/local_notification_storage.dart';
import '../models/user_notification.dart';
import 'package:shimmer/shimmer.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _dashboardFuture;
  late Future<bool> _isBuddhistDayFuture;
  late Future<Map<String, dynamic>> _userInfoFuture;
  int _unreadCount = 0;
  bool _isNotificationEnabled = false;

  @override
  void initState() {
    super.initState();
    // Initialize dashboard future - this will be used by FutureBuilder
    _dashboardFuture = _initializeDashboard();
    _isBuddhistDayFuture = ApiService.isBuddhistDayToday();
    _userInfoFuture = AuthService.getUserInfo();
    _checkNotification();
    _loadNotificationSetting(); // Load setting
    
    // Init notification service
    NotificationService().init();
    
    // Clear old shipping address notifications and then auto-enable
    _initializeNotifications();

    // Listen to DIRECT unread count changes (Instant Update)
    ApiService.unreadNotificationCount.addListener(() {
      if (mounted) {
        setState(() {
          _unreadCount = ApiService.unreadNotificationCount.value;
        });
      }
    });

    // Listen for refresh signals from other pages (e.g. AnalyzerPage after saving)
    ApiService.dashboardRefreshSignal.addListener(() {
      if (mounted) {
         _loadDashboard();
         _checkNotification(); // Ensure notification count updates immediately!
      }
    });
  }

  Future<Map<String, dynamic>> _initializeDashboard() async {
    try {
      final data = await ApiService.getDashboard();
      return data;
    } catch (e) {
      // Rethrow to let FutureBuilder handle it
      rethrow;
    }
  }

  Future<void> _initializeNotifications() async {
    // Auto-enable notifications on first launch
    await _autoEnableNotificationsOnFirstLaunch();
  }

  Future<void> _autoEnableNotificationsOnFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasConfigured = prefs.containsKey('buddhist_notification_enabled');
    
    if (!hasConfigured) {
      // First time - try to auto-enable
      _toggleNotification(true);
    }
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationEnabled = prefs.getBool('buddhist_notification_enabled') ?? true; // Default: enabled
    });
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Show Loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const CircularProgressIndicator(color: Colors.amber),
          ),
        ),
      );
    }

    try {
      if (value) {
        // Enable
        bool granted = await NotificationService().requestPermissions();
        if (!granted) {
          if (mounted) {
            Navigator.pop(context); // Remove loading
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('การแจ้งเตือนถูกปิดอยู่', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
                content: Text('กรุณาอนุญาตการแจ้งเตือนใน "การตั้งค่า" ของตัวเครื่อง เพื่อรับข่าวสารวันพระ', style: GoogleFonts.kanit()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('รับทราบ', style: GoogleFonts.kanit()),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: Text('ไปที่ตั้งค่า', style: GoogleFonts.kanit(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
          return;
        }

        final days = await ApiService.getBuddhistDays();
        await NotificationService().scheduleBuddhistDayNotifications(days);
        
        if (mounted) CustomToast.show(context, 'เปิดการแจ้งเตือนวันพระเรียบร้อยแล้ว');
      } else {
        // Disable
        await NotificationService().cancelAll();
        if (mounted) CustomToast.show(context, 'ปิดการแจ้งเตือนแล้ว');
      }

      // Success - Update state
      await prefs.setBool('buddhist_notification_enabled', value);
      if (mounted) {
        setState(() {
          _isNotificationEnabled = value;
        });
        _checkNotification();
      }
    } catch (e) {
      print("❌ Error in toggle notification: $e");
      if (mounted) CustomToast.show(context, 'เกิดข้อผิดพลาดในการตั้งค่า', isSuccess: false);
    } finally {
      if (mounted) Navigator.pop(context); // Remove loading
    }
  }


  @override
  void dispose() {
    ApiService.dashboardRefreshSignal.removeListener(_loadDashboard);
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    // Check previous VIP status before fetching
    final prefs = await SharedPreferences.getInstance();
    final wasVip = prefs.getBool(AuthService.keyIsVip) ?? false;

    // Reload User Notifs / Unread Count
    ApiService.getUserNotifications().then((notifs) {
       // logic...
       // Force Update UI
       if (mounted) {
         _checkNotification(); // Re-run the full check to update _unreadCount
       }
    });
    
    // Reload Dashboard Data
    try {
      final dashboardData = await ApiService.getDashboard(); // Keep original API call
      if (mounted) {
        setState(() {
          _dashboardFuture = Future.value(dashboardData);
        });

        // Handle VIP and Session Logic
        final isVip = dashboardData['is_vip'] == true || dashboardData['IsVIP'] == true;
        if (wasVip && !isVip) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context, 
                builder: (_) => AlertDialog(
                  title: Text('สถานะ VIP หมดอายุ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.orange)),
                  content: Text('คุณสามารถต่ออายุ VIP ได้โดยการกรอกรหัส VIP ใหม่', style: GoogleFonts.kanit()),
                  actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text('ตกลง', style: GoogleFonts.kanit()))]
                )
              );
            });
        }
      }
    } catch (error) {
       // Handle Errors like 403/Suspended
       if (error.toString().contains('suspended') || error.toString().contains('403')) {
          if (mounted) {
             AuthService.logout();
             Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainTabPage(initialIndex: 0)),
                (route) => false,
             );
          }
       }
       // Don't throw if just refreshing, but FutureBuilder needs a future
       // _dashboardFuture is already set so we can leave it or set error
    }
  }

      Future<void> _checkNotification() async {
          try {
            print('🔔 [Dashboard] Refreshing counts...');
            
            List<UserNotification> serverNotifs = [];
            List<UserNotification> localNotifs = [];
            Set<int> hiddenIds = {};

            try {
              final results = await Future.wait([
                ApiService.getUserNotifications().timeout(const Duration(seconds: 5)),
                LocalNotificationStorage.getAll(),
                LocalNotificationStorage.getHiddenServerIds(),
              ]);
              serverNotifs = results[0] as List<UserNotification>;
              localNotifs = results[1] as List<UserNotification>;
              hiddenIds = (results[2] as List<int>).toSet();
            } catch (e) {
              print('⚠️ [Dashboard] Partial fetch failure: $e');
              // Fallback: use whatever we have in local storage
              localNotifs = await LocalNotificationStorage.getAll();
              hiddenIds = (await LocalNotificationStorage.getHiddenServerIds()).toSet();
            }
    
            final Map<String, UserNotification> uniqueUnread = {};
            
            // Priority 1: Server (Source of truth)
            // For server notifications, they are unique by ID. 
            // We group by title_message_date to handle local vs server matching later.
            for (var n in serverNotifs) {
                if (!n.isRead && !hiddenIds.contains(n.id)) {
                    // Use a more unique key for counting: id itself
                    uniqueUnread["server_${n.id}"] = n;
                }
            }
            
            // Priority 2: Local
            // Only count local unread if it doesn't match an unread server notification
            for (var n in localNotifs) {
                if (!n.isRead) {
                    // Check if this matches ANY server notification (unread or read) 
                    // that arrived within the same hour
                    bool existsOnServer = serverNotifs.any((sn) => 
                      sn.title == n.title && 
                      sn.message == n.message &&
                      sn.createdAt.difference(n.createdAt).inHours.abs() < 1
                    );
                    
                    if (!existsOnServer) {
                       uniqueUnread["local_${n.id}"] = n;
                    }
                }
            }
            
            int total = uniqueUnread.length;
            print('✅ [Dashboard] Unread Count Updated: $total (Server: ${serverNotifs.where((n)=>!n.isRead).length}, Local Unique: ${total - serverNotifs.where((n)=>!n.isRead).length})');
    
            if (mounted) {
               ApiService.unreadNotificationCount.value = total;
               setState(() {
                 _unreadCount = total;
               });
            }
          } catch (e) {
            debugPrint('❌ [Dashboard] Critical error in _checkNotification: $e');
          }
      }

  void _showNotificationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: const NotificationListPage(isBottomSheet: true),
      ),
    ).then((_) => _checkNotification());
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
  Future<void> _confirmLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('ยืนยันออกจากระบบ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: Text('คุณต้องการออกจากระบบใช่หรือไม่?', style: GoogleFonts.kanit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              // Directly logout and navigate to clear everything including the dialog
              try {
                await AuthService.logout();
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => MainTabPage(initialIndex: 0, forceLogout: true)),
                    (route) => false,
                  );
                }
              } catch (e) {
                print("Logout navigation error: $e");
              }
            },
            child: Text('ออกจากระบบ', style: GoogleFonts.kanit(color: Colors.red, fontWeight: FontWeight.bold)),
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
                  return _buildSkeleton();
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

              return AdaptiveFooterScrollView(
                onRefresh: () async => _loadDashboard(),
                children: [
                  // 1. Premium Header with Avatar
                  _buildPremiumHeader(context, username, email, avatarUrl, isVip, isAdmin, hasAddress),

                  // Buddhist Day Banner
                  FutureBuilder<bool>(
                    future: _isBuddhistDayFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data == true) {
                        return Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'วันนี้วันพระ',
                                      style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    Text(
                                      'ทำจิตใจให้ผ่องใส คิดดี ทำดี พูดดี',
                                      style: GoogleFonts.kanit(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        _buildMenuCard(context, hasAddress, List<String>.from(data['assigned_colors'] ?? [])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, String username, String email, String? avatarUrl, bool isVip, bool isAdmin, bool hasAddress) {
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
      child: Stack(
        children: [
          // Content Layer (Center Aligned)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               // Avatar with Glow & Admin Badge
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
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.verified_user, color: Colors.white, size: 16),
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

          // Top Buttons (Notification + Logout) - Moved to be LAST child for highest Z-Index
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              children: [
                // Notification Bell
                const NotificationBell(),
                const SizedBox(width: 4),
                // Subtle Logout Icon
                IconButton(
                  onPressed: _confirmLogout,
                  icon: Icon(Icons.logout_rounded, color: Colors.grey[400], size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  tooltip: 'ออกจากระบบ',
                ),
              ],
            ),
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
  Widget _buildMenuCard(BuildContext context, bool hasAddress, List<String> assignedColors) {
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
           if (assignedColors.isNotEmpty) ...[
             _buildMenuItem(
               context,
               icon: Icons.account_balance_wallet_outlined,
               title: 'สีกระเป๋ามงคล',
               iconColor: Colors.deepPurpleAccent,
               onTap: () => WalletColorBottomSheet.show(context, assignedColors),
             ),
             const Divider(height: 1, indent: 60),
           ],
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
           SwitchListTile(
              value: _isNotificationEnabled,
              onChanged: _toggleNotification,
              title: Text('แจ้งเตือนวันพระ', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: Text('รับการแจ้งเตือนวันสำคัญทางศาสนา', style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey)),
              secondary: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_outlined, color: Colors.amber, size: 22),
              ),
              activeColor: Colors.amber,
              contentPadding: const EdgeInsets.only(left: 16, right: 8),
           ),
           const Divider(height: 1, indent: 60),
           _buildMenuItem(
             context,
             icon: Icons.logout,
             title: 'ออกจากระบบ',
             iconColor: Colors.redAccent,
             onTap: _confirmLogout,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD700), width: 1), // Gold border
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.2), // Soft gold shadow
            blurRadius: 20,
            offset: const Offset(0, 5),
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
                  color: const Color(0xFFFFD700).withOpacity(0.1), // Gold tint for all
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
                                color: const Color(0xFFB8860B), // Dark Goldenrod text
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isVip)
                              Text(
                                'PREMIUM ACCESS UNLOCKED',
                                style: GoogleFonts.kanit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB8860B).withOpacity(0.6),
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
                      color: Colors.black87, // Dark text
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPrivilegeItem('วิเคราะห์ความหมายคู่เลขไม่จำกัด'),
                  _buildPrivilegeItem('เข้าถึงฐานข้อมูล 300,000+ ชื่อ'),
                  _buildPrivilegeItem('วิเคราะห์ตามตำราโบราณครบทุกชั้น'),
                  if (!isVip) ...[
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6), // Light gold/cream background for inner section
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.confirmation_number_outlined, color: Color(0xFFB8860B), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'มีรหัสโปรโมชันหรือรหัส VIP?', 
                                style: GoogleFonts.kanit(fontSize: 15, color: const Color(0xFF8B6914), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'กรอกรหัส VIP ที่ได้จากกิจกรรม หรือท่านจะได้เป็น VIP อัตโนมัติเมื่อซื้อสินค้าร้าน "ร้านมาดี"', 
                            style: GoogleFonts.kanit(fontSize: 12, color: Colors.black54, height: 1.4),
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
                                            Text('ใส่รหัส VIP', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, fontSize: 14)),
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
                                        foregroundColor: const Color(0xFFB8860B),
                                        side: const BorderSide(color: Color(0xFFB8860B), width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.shopping_bag_outlined, size: 18),
                                          const SizedBox(width: 8),
                                          Text('ร้านมาดี', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
        title: Text('ใส่รหัส VIP', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
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
                color: Colors.black87, // Changed from white for visibility on white background
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
                const Icon(Icons.logout, size: 18, color: Colors.redAccent), // Red color for visibility
                const SizedBox(width: 8),
                Text('ออกจากระบบ', 
                  style: GoogleFonts.kanit(
                    fontSize: 14, 
                    color: Colors.redAccent, // Red color text
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
      clipBehavior: Clip.antiAlias,
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
                const SizedBox(width: 24), // Space for >> icon
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

            // Check if this is a "perfect" name: all pairs good (green) - no bad pairs
            final hasSatPairs = satPairs.length >= 1; // At least 1 pair
            final hasShaPairs = shaPairs.length >= 1; // At least 1 pair
            
            // Check if all pairs are good (not bad)
            bool allSatGood = true;
            for (var p in satPairs.take(2)) {
              if (p['is_bad'] == true || p['IsBad'] == true) {
                allSatGood = false;
                break;
              }
            }
            
            bool allShaGood = true;
            for (var p in shaPairs.take(2)) {
              if (p['is_bad'] == true || p['IsBad'] == true) {
                allShaGood = false;
                break;
              }
            }
            
            // Check if name has any bad characters (kalakini)
            bool hasKalakini = false;
            for (var charData in displayNameHtml) {
              if (charData['is_bad'] == true || charData['IsBad'] == true) {
                hasKalakini = true;
                break;
              }
            }
            
            final isPerfect = hasSatPairs && hasShaPairs && allSatGood && allShaGood && !hasKalakini; // All green pairs + no kalakini characters
            
            // Debug log - show details for first item only
            if (index == 0) {
              print('🔍 DEBUG First saved name: $name');
              print('   hasSatPairs: $hasSatPairs (${satPairs.length} pairs)');
              print('   hasShaPairs: $hasShaPairs (${shaPairs.length} pairs)');
              print('   allSatGood: $allSatGood');
              print('   allShaGood: $allShaGood');
              print('   isPerfect: $isPerfect');
              print('   isTopTier: $isTopTier');
            }
            
            // Debug second item to find kalakini field
            if (index == 1 && name == 'ภูดิท') {
              print('🔍 DEBUG Second saved name (ภูดิท) - ALL DATA:');
              print('   Full data: $nameData');
            }
            
            if (isPerfect) {
              print('✨ PERFECT NAME FOUND: $name (Has star: $isTopTier, Will apply gold shimmer animation)');
            }

            final rowWidget = Dismissible(
              key: Key('saved_name_$id'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: const Icon(Icons.delete, color: Colors.white, size: 28),
              ),
              confirmDismiss: (direction) async {
                // Show confirmation dialog first
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('ยืนยันการลบ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
                      content: Text('คุณต้องการลบ "$name" ใช่หรือไม่?', style: GoogleFonts.kanit()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: Text('ลบ', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                );
                
                // If user confirmed, perform the delete
                if (confirmed == true) {
                  try {
                    final msg = await ApiService.deleteSavedName(id);
                    if (mounted) {
                      CustomToast.show(context, msg);
                      // Reload dashboard after successful delete
                      _loadDashboard();
                    }
                    return true; // Allow dismissal
                  } catch (e) {
                    if (mounted) {
                      CustomToast.show(context, e.toString().replaceAll('Exception: ', ''), isSuccess: false);
                    }
                    return false; // Prevent dismissal on error
                  }
                }
                
                return false; // User cancelled
              },
              onDismissed: (direction) {
                // This will only be called if confirmDismiss returns true
                // No need to do anything here since we already handled it in confirmDismiss
              },
              child: InkWell(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => AnalyzerPage(initialName: name, initialDay: birthDayRaw)));
                _loadDashboard();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isPerfect 
                      ? const Color(0xFFFFFBE6) // Very light cream/gold background (lighter than before)
                      : (isTopTier ? const Color(0xFFFFFDE7) : (index % 2 == 0 ? Colors.white : Colors.grey[50])),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                    left: isPerfect 
                        ? const BorderSide(color: Color(0xFFFFD700), width: 4) // Gold border for perfect
                        : (isTopTier ? const BorderSide(color: Color(0xFFFBC02D), width: 3) : BorderSide.none),
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
                                child: _ShimmeringGoldWrapper(
                                  enabled: isPerfect,
                                  child: displayNameHtml.isEmpty
                                    ? Text(
                                        name,
                                        style: GoogleFonts.kanit(
                                          fontSize: 14,
                                          fontWeight: (isTopTier || isPerfect) ? FontWeight.w800 : FontWeight.bold,
                                          color: (isTopTier || isPerfect) ? const Color(0xFFB8860B) : Colors.black87,
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
                                                    fontWeight: (isTopTier || isPerfect) ? FontWeight.w800 : FontWeight.bold,
                                                    color: isBad ? const Color(0xFFFF4757) : ((isTopTier || isPerfect) ? const Color(0xFFB8860B) : Colors.black87),
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
                    // Column 5: Analyze Icon (>>)
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00C853).withOpacity(0.15), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C853).withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        color: Color(0xFF00C853),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );

            // Perfect names already have gold background and border - no animation for now
            return rowWidget;
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMiniPairCircle(dynamic p) {
    final num = p['number'] ?? p['Number'] ?? '??';
    var colorStr = p['color'] ?? p['Color'] ?? '#CCCCCC';
    final type = (p['type'] ?? p['Type'] ?? '').toString().toUpperCase();

    // Robust Bad Check (Matches Analyzer Page logic)
    final isBad = type.startsWith('R') || 
                  type.contains('BAD') ||
                  colorStr.toString().toUpperCase().contains('EF4444') || 
                  colorStr.toString().toUpperCase().contains('D32F2F');

    if (isBad) {
      colorStr = '#EF4444'; // Force Red
    }

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
          const SizedBox(height: 20),
          // Debug FCM Token
          ValueListenableBuilder<String>(
            valueListenable: NotificationService.debugTokenLog,
            builder: (context, value, child) {
              if (value.isEmpty) return const SizedBox();
              return SelectableText(
                "DEBUG FCM: $value",
                style: const TextStyle(fontSize: 10, color: Colors.red),
                textAlign: TextAlign.center,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            // Header Skeleton
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            // Privilege Card Skeleton
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Section Header Skeleton
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(width: 150, height: 24, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Table/Items Skeleton
            ...List.generate(3, (index) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// Shimmering Gold Animation for Perfect Names (copied from analyzer_page.dart)
class _ShimmeringGoldWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _ShimmeringGoldWrapper({required this.child, this.enabled = true});

  @override
  State<_ShimmeringGoldWrapper> createState() => _ShimmeringGoldWrapperState();
}

class _ShimmeringGoldWrapperState extends State<_ShimmeringGoldWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 3000)
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Color(0xFF8B6914), // Darker Gold
                Color(0xFFFFD700), // Gold
                Color(0xFFFFF8DC), // Cornsilk
                Color(0xFFFFD700), // Gold
                Color(0xFF8B6914),
              ],
              stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
              begin: Alignment(-3.0 + (4.0 * _controller.value), -0.5),
              end: Alignment(-1.0 + (4.0 * _controller.value), 0.5),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
