import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../screens/notification_list_page.dart';

class NotificationBell extends StatelessWidget {
  final Color iconColor;
  final bool isWhiteBackground;

  const NotificationBell({
    super.key,
    this.iconColor = Colors.grey,
    this.isWhiteBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ApiService.unreadNotificationCount,
      builder: (context, count, child) {
        print("🔔 NotificationBell: Building with count = $count (IsWhite: $isWhiteBackground)");
        return Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              onPressed: () {
                _showNotificationsBottomSheet(context);
              },
              icon: Icon(
                Icons.notifications_none_rounded, 
                color: iconColor, 
                size: 28
              ),
              tooltip: 'การแจ้งเตือน',
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isWhiteBackground ? Colors.white : Colors.transparent, 
                      width: 1.5
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: GoogleFonts.kanit(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: const NotificationListPage(isBottomSheet: true),
      ),
    ).then((_) {
      // Trigger a re-check or just let the local logic handle it
      // _checkNotification() logic is mainy in Dashboard, 
      // but ApiService.unreadNotificationCount will be updated by NotificationListPage
      // when items are marked as read.
    });
  }
}
