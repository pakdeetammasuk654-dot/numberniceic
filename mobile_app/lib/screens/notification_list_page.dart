import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_notification.dart';
import '../services/api_service.dart';
import '../services/local_notification_storage.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../widgets/shared_footer.dart';
import '../widgets/adaptive_footer_scroll_view.dart';

import '../widgets/wallet_color_bottom_sheet.dart';
import 'shipping_address_page.dart';
import '../services/auth_service.dart';
import 'articles_page.dart';
import 'article_detail_page.dart';

import 'dart:async';
import '../services/notification_service.dart';

class NotificationListPage extends StatefulWidget {
  final bool isBottomSheet;
  const NotificationListPage({super.key, this.isBottomSheet = false});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  List<UserNotification>? _notifications;
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _notifSubscription;
  
  // Track all IDs for each unique notification key (title_message)
  final Map<String, List<int>> _notifIdGroups = {};

  @override
  void initState() {
    super.initState();
    _clearAndLoad();
    
    // Auto-refresh when a new notification arrives (foreground)
    _notifSubscription = NotificationService().messageStream.listen((message) {
      if (message.data['tapped'] == 'true') return; // Ignore tap events, only handle foreground arrivals
      
      final title = message.notification?.title ?? message.data['title'] ?? 'การแจ้งเตือน';
      final body = message.notification?.body ?? message.data['message'] ?? message.data['body'] ?? '';
      
      print("🔔 [NotificationListPage] STREAM RECEIVED: $title");
      
      final newNotif = UserNotification(
        id: message.hashCode,
        title: title,
        message: body,
        isRead: false,
        createdAt: DateTime.now(),
        data: message.data,
      );

      if (mounted) {
        setState(() {
          // Use a very specific key for stream injection to avoid swallowing distinct but similar test messages
          final streamKey = "${newNotif.title}_${newNotif.message}_${newNotif.createdAt.millisecondsSinceEpoch}";
          
          _notifications ??= [];
          _notifications!.insert(0, newNotif);
          _notifIdGroups[streamKey] = [newNotif.id];
          
          print("✅ [NotificationListPage] Injected successfully (ID: ${newNotif.id}).");
        });
        
        // Background sync after a short delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _loadData(isInitial: false);
        });
      }
    });
  }
  
  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  Future<void> _clearAndLoad() async {
    // Clear problematic notifications FIRST before any loading
    await LocalNotificationStorage.clearShippingAddressNotifications();
    // Then load the data
    _loadData(isInitial: true);
  }

  String _formatThaiDate(DateTime date) {
    // Format Month in Thai, and add 543 to Year for BE
    final localDate = date.toLocal();
    final formatter = DateFormat('dd MMM', 'th');
    final timeFormatter = DateFormat('HH:mm');
    return '${formatter.format(localDate)} ${localDate.year + 543} ${timeFormatter.format(localDate)}';
  }

  Future<void> _loadData({bool isInitial = false}) async {
    try {
      if (isInitial && mounted && _notifications == null) {
        setState(() => _isLoading = true);
      }
      
      print("🔔 [NotificationListPage] Loading data... (isInitial: $isInitial)");
      
      // Load everything in parallel
      final results = await Future.wait([
        ApiService.getUserNotifications(),
        LocalNotificationStorage.getAll(),
        LocalNotificationStorage.getHiddenServerIds(),
      ]);
      
      final serverNotifs = results[0] as List<UserNotification>;
      final localNotifs = results[1] as List<UserNotification>;
      final hiddenIds = (results[2] as List<int>).toSet();
      
      _updateUI(
        serverNotifs: serverNotifs, 
        localNotifs: localNotifs, 
        hiddenIds: hiddenIds
      );
    } catch (e) {
      print("❌ Error loading notifications: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _updateUI({
    required List<UserNotification> serverNotifs, 
    required List<UserNotification> localNotifs, 
    required Set<int> hiddenIds,
  }) {
      _notifIdGroups.clear();
      final List<UserNotification> combined = [];
      
      // 1. Add Filtered Server Notifications (Master List)
      final filteredServer = serverNotifs.where((n) => !hiddenIds.contains(n.id)).toList();
      for (var n in filteredServer) {
          combined.add(n);
          // Group key for merging: Content + Hour
          final groupKey = "${n.title}_${n.message}_${n.createdAt.year}${n.createdAt.month}${n.createdAt.day}${n.createdAt.hour}";
          _notifIdGroups.putIfAbsent(groupKey, () => []).add(n.id);
      }
      
      // 2. Add Local Notifications if they are unique
      for (var n in localNotifs) {
          final groupKey = "${n.title}_${n.message}_${n.createdAt.year}${n.createdAt.month}${n.createdAt.day}${n.createdAt.hour}";
          
          bool hasMatchingServer = filteredServer.any((sn) => 
            sn.title == n.title && 
            sn.message == n.message &&
            sn.createdAt.difference(n.createdAt).inHours.abs() < 1
          );
          
          if (!hasMatchingServer) {
            combined.add(n);
            _notifIdGroups.putIfAbsent(groupKey, () => []).add(n.id);
          } else {
            // It matches a server entry, associate the local ID with the server entry's group
            _notifIdGroups.putIfAbsent(groupKey, () => []).add(n.id);
          }
      }
      
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _notifications = combined;
          _isLoading = false;
          _error = null;
        });
        print("✅ [NotificationListPage] UI Sync'd: ${combined.length} unique items shown.");
      }
  }

  void _deleteNotification(int id) async {
    // 1. Check if notification was unread BEFORE removing it
    final notif = _notifications?.firstWhere((n) => n.id == id, orElse: () => UserNotification(
      id: 0, title: '', message: '', isRead: true, createdAt: DateTime.now(),
    ));
    
    final wasUnread = notif != null && !notif.isRead;
    
    // 2. Update UI Immediately (Optimistic Update)
    if (_notifications != null) {
      setState(() {
        _notifications = _notifications!.where((n) => n.id != id).toList();
      });
    }

    // 3. Decrement unread count if notification was unread
    if (wasUnread && ApiService.unreadNotificationCount.value > 0) {
      ApiService.unreadNotificationCount.value--;
      print('🔔 Deleted unread notification. Count: ${ApiService.unreadNotificationCount.value}');
    }

    // 4. Perform background storage task
    await LocalNotificationStorage.delete(id);
    
    // 5. If it's a server notification, delete it on the server 
    // so it's gone from the database.
    // Server IDs are typically small integers, while local IDs are large timestamps.
    if (id < 1000000000) {
      try {
        await ApiService.deleteNotification(id);
      } catch (e) {
        debugPrint('Error deleting notif on server: $e');
      }
    }
  }

  void _markLocallyAsRead(int id) {
    if (_notifications != null) {
      setState(() {
        _notifications = _notifications!.map((n) {
          if (n.id == id) {
            // Since UserNotification is often immutable (final fields), 
            // we should ideally have a copyWith but we'll check the model.
            // For now, let's just trigger a re-render if we can or wait for next load.
            // If we can't mutate, we skip immediate bold-to-normal change 
            // but the delete is what's most important for the "flash" issue.
            return n; 
          }
          return n;
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isBottomSheet) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle & Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                   const SizedBox(height: 24), // Increased spacing
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'การแจ้งเตือน',
                          style: GoogleFonts.kanit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        if (_notifications != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '(${_notifications!.length})',
                              style: GoogleFonts.kanit(color: Colors.grey, fontSize: 14),
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('การแจ้งเตือน', style: GoogleFonts.kanit(color: Colors.white)),
            if (_notifications != null)
              Text(
                'items: ${_notifications!.length}', 
                style: GoogleFonts.kanit(color: Colors.white70, fontSize: 10)
              ),
          ],
        ),
        backgroundColor: const Color(0xFF333333),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _notifications == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null && _notifications == null) {
      return Center(child: Text('Error: $_error'));
    }

    final notifications = _notifications ?? [];

    return AdaptiveFooterScrollView(
      onRefresh: _loadData,
      children: [
        const SizedBox(height: 16),
        if (notifications.isEmpty)
          SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('ไม่มีการแจ้งเตือน', style: GoogleFonts.kanit(fontSize: 18, color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ...notifications.map((notif) => Dismissible(
            key: Key('notif_${notif.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 32),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text('ยืนยันการลบ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
                  content: Text('คุณต้องการลบการแจ้งเตือนนี้ใช่หรือไม่?', style: GoogleFonts.kanit()),
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
            },
            onDismissed: (direction) {
              _deleteNotification(notif.id);
            },
            child: Column(
              children: [
                ListTile(
                  tileColor: notif.isRead ? Colors.white : Colors.orange.withOpacity(0.05),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: notif.isRead ? Colors.grey[100] : Colors.orange[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_rounded,
                      color: notif.isRead ? Colors.grey[400] : Colors.orange,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    notif.title,
                    style: GoogleFonts.kanit(
                      fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.kanit(fontSize: 14, color: Colors.blueGrey[600]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatThaiDate(notif.createdAt),
                        style: GoogleFonts.kanit(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
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
                      size: 20,
                    ),
                  ),
                  onTap: () {
                    _showNotificationDetail(notif);
                  },
                ),
                const Divider(height: 1, indent: 72, endIndent: 16),
              ],
            ),
          )),
      ],
    );
  }

  void _confirmDelete(int id) {
     // This method can be removed as we use inline confirmation in Dismissible
     // or keep it if needed for the detail view delete button.
     showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('ยืนยันการลบ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: Text('คุณต้องการลบการแจ้งเตือนนี้ใช่หรือไม่?', style: GoogleFonts.kanit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNotification(id);
            },
            child: Text('ลบ', style: GoogleFonts.kanit(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  void _showNotificationDetail(UserNotification notif) async {
    // Mark as read immediately
    if (!notif.isRead) {
      final key = "${notif.title}_${notif.message}";
      final ids = _notifIdGroups[key] ?? [notif.id];
      
      print('🔔 Marking group as read: $ids ($key)');
      
      for (var id in ids) {
        if (id < 99999999) { 
          ApiService.markNotificationAsRead(id);
        }
        LocalNotificationStorage.markAsRead(id);
      }
      
      // Decrement unread count (by exactly 1 unique item)
      if (ApiService.unreadNotificationCount.value > 0) {
        ApiService.unreadNotificationCount.value--;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notif.title,
                style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _formatThaiDate(notif.createdAt),
                style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 24),
              SingleChildScrollView(
                 child: Text(
                    notif.message,
                    style: GoogleFonts.kanit(fontSize: 16, height: 1.5),
                 ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (notif.data?['type'] == 'payment_success' || notif.title.contains('ที่อยู่') || notif.message.contains('ที่อยู่'))
                      _build3DButton(
                        label: 'จัดการที่อยู่',
                        icon: Icons.local_shipping_outlined,
                        color: Colors.blue[600]!,
                        shadowColor: Colors.blue[900]!,
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ShippingAddressPage()));
                        },
                      ),
                    if (notif.title.contains('วันพระ'))
                      _build3DButton(
                        label: 'อ่านบทความ',
                        icon: Icons.menu_book_rounded,
                        color: Colors.orange[600]!,
                        shadowColor: Colors.orange[900]!,
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ArticlesPage()));
                        },
                      ),
                    if (notif.data?['type'] == 'article' && notif.data?['article_slug'] != null)
                      _build3DButton(
                        label: 'อ่านฉบับเต็ม',
                        icon: Icons.article_rounded,
                        color: Colors.teal[600]!,
                        shadowColor: Colors.teal[900]!,
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ArticleDetailPage(slug: notif.data!['article_slug']!),
                            ),
                          );
                        },
                      ),
                    if (notif.data?['type'] == 'wallet_colors' && notif.data?['colors'] != null)
                      _build3DButton(
                        label: 'ดูสีกระเป๋า',
                        icon: Icons.account_balance_wallet_rounded,
                        color: Colors.amber[700]!,
                        shadowColor: Colors.amber[900]!,
                        onPressed: () {
                          Navigator.pop(context);
                          try {
                            // Data format example: "['#FF0000', '#00FF00']" or "#FF0000,#00FF00"
                            // Backend sends simple comma separated usually if map map[string]string
                            String raw = notif.data!['colors']!;
                            List<String> colors = [];
                            if (raw.startsWith('[')) {
                               // Simple trim if JSON-like string
                               colors = raw.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", "").split(',');
                            } else {
                               colors = raw.split(',');
                            }
                            colors = colors.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                            
                            WalletColorBottomSheet.show(context, colors);
                          } catch (e) {
                             print('Error parsing wallet colors: $e');
                          }
                        },
                      ),
                    
                    // Fallback for notifications from DB (History) where data is missing
                    if (notif.data?['type'] != 'wallet_colors' && notif.title.contains('สีกระเป๋า'))
                      FutureBuilder<Map<String, dynamic>>(
                        future: AuthService.getUserInfo(), // Fetch colors from profile
                        builder: (context, snapshot) {
                           if (!snapshot.hasData) return const SizedBox.shrink();
                           
                           final raw = snapshot.data!['assigned_colors'];
                           if (raw == null) return const SizedBox.shrink();
                           
                           List<String> colors = [];
                           if (raw is List) {
                             colors = raw.map((e) => e.toString()).toList();
                           } else if (raw is String && raw.isNotEmpty) {
                             colors = raw.split(',');
                           }
                           
                           colors = colors.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                           
                           if (colors.isEmpty) return const SizedBox.shrink();
                           
                           return Padding(
                             padding: const EdgeInsets.only(right: 12),
                             child: _build3DButton(
                              label: 'ดูสีกระเป๋า',
                              icon: Icons.account_balance_wallet_rounded,
                              color: Colors.amber[700]!,
                              shadowColor: Colors.amber[900]!,
                              onPressed: () {
                                Navigator.pop(context);
                                WalletColorBottomSheet.show(context, colors);
                              },
                             ),
                           );
                        }
                      ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                      child: Text('ปิด', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.w500)),
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

  Widget _build3DButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color shadowColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.kanit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
