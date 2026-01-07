import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_notification.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  late Future<List<UserNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _notificationsFuture = ApiService.getUserNotifications();
    });
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
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<UserNotification>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('ไม่มีการแจ้งเตือน', style: GoogleFonts.kanit(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              );
            }

            final notifications = snapshot.data!;
            return ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return ListTile(
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
                        DateFormat('dd MMM yyyy HH:mm').format(notif.createdAt),
                        style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () {
                    _showNotificationDetail(notif);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showNotificationDetail(UserNotification notif) async {
    // Mark as read immediately
    if (!notif.isRead) {
      await ApiService.markNotificationAsRead(notif.id);
      _refresh(); // Refresh list to update UI UI
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
                DateFormat('dd MMM yyyy HH:mm').format(notif.createdAt),
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
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ปิด', style: GoogleFonts.kanit(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
