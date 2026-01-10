import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_notification.dart';
import '../services/api_service.dart';
import '../services/local_notification_storage.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../widgets/shared_footer.dart';
import '../widgets/adaptive_footer_scroll_view.dart';
import 'shipping_address_page.dart';
import 'articles_page.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  List<UserNotification>? _notifications;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clearAndLoad();
  }

  Future<void> _clearAndLoad() async {
    // Clear problematic notifications FIRST before any loading
    await LocalNotificationStorage.clearShippingAddressNotifications();
    // Then load the data
    _loadData();
  }

  String _formatThaiDate(DateTime date) {
    // Format Month in Thai, and add 543 to Year for BE
    final formatter = DateFormat('dd MMM', 'th');
    final timeFormatter = DateFormat('HH:mm');
    return '${formatter.format(date)} ${date.year + 543} ${timeFormatter.format(date)}';
  }

  Future<void> _loadData() async {
    try {
      // Always show loading when clearing/refreshing
      setState(() => _isLoading = true);
      
      // Clear shipping address notifications first
      await LocalNotificationStorage.clearShippingAddressNotifications();
      
      final serverList = await ApiService.getUserNotifications();
      final localList = await LocalNotificationStorage.getAll();
      final hiddenIds = await LocalNotificationStorage.getHiddenServerIds();
      
      final combined = [
        ...serverList.where((n) => !hiddenIds.contains(n.id)),
        ...localList
      ];
      
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      if (mounted) {
        setState(() {
          _notifications = combined;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _deleteNotification(int id) async {
    // 1. Update UI Immediately (Optimistic Update)
    if (_notifications != null) {
      setState(() {
        _notifications = _notifications!.where((n) => n.id != id).toList();
      });
    }

    // 2. Perform background storage task
    await LocalNotificationStorage.delete(id);
    
    // 3. If it's a server notification, mark it as read on the server 
    // so the unread count in dashboard is correct.
    // Server IDs are typically small integers, while local IDs are large timestamps.
    if (id < 1000000000) {
      try {
        await ApiService.markNotificationAsRead(id);
      } catch (e) {
        debugPrint('Error marking deleted notif as read on server: $e');
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('การแจ้งเตือน', style: GoogleFonts.kanit(color: Colors.white)),
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
        const SizedBox(height: 16), // Added spacing at the top
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
          ...notifications.map((notif) => Column(
            children: [
              ListTile(
                tileColor: notif.isRead ? Colors.white : Colors.orange.withOpacity(0.05),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: notif.isRead ? Colors.grey[200] : Colors.orange[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications,
                    color: notif.isRead ? Colors.grey : Colors.orange,
                  ),
                ),
                title: Text(
                  notif.title,
                  style: GoogleFonts.kanit(
                    fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.kanit(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatThaiDate(notif.createdAt),
                      style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 26),
                  onPressed: () => _confirmDelete(notif.id),
                ),
                onTap: () {
                  _showNotificationDetail(notif);
                },
              ),
              const Divider(height: 1),
            ],
          )),
      ],
    );
  }

  void _confirmDelete(int id) {
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
      if (notif.id < 99999999) { 
        ApiService.markNotificationAsRead(notif.id);
      }
      LocalNotificationStorage.markAsRead(notif.id);
      // To avoid flickering, we don't call _loadData() here.
      // The bold will turn to normal next time the page is opened or refreshed.
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
                    if (notif.title.contains('ที่อยู่'))
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ShippingAddressPage()));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: Text('ไปหน้าเพิ่มที่อยู่', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
                      ),
                    if (notif.title.contains('วันพระ'))
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ArticlesPage()));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        child: Text('อ่านบทความแนะนำ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () {
                        Navigator.pop(context); // Close detail dialog
                        _confirmDelete(notif.id); // Show confirm delete dialog
                      },
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('ปิด', style: GoogleFonts.kanit(fontSize: 16, color: Colors.grey)),
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
}
