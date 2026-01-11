import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_notification.dart';

class LocalNotificationStorage {
  static const String _key = 'local_user_notifications';

  static Future<void> save(String title, String message) async {
    final prefs = await SharedPreferences.getInstance();
    // Reload list to get latest state
    await prefs.reload(); 
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    final newNotif = {
      'id': DateTime.now().millisecondsSinceEpoch, 
      'title': title,
      'message': message,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    list.add(jsonEncode(newNotif));
    if (list.length > 50) list.removeRange(0, list.length - 50);
    
    await prefs.setStringList(_key, list);
    print("✅ LocalNotificationStorage: Saved new notification '${title}' (Total: ${list.length})");
  }

  static Future<List<UserNotification>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Ensure we have the latest data
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    return list.map((item) {
      final map = jsonDecode(item);
      return UserNotification.fromJson(map);
    }).toList().reversed.toList();
  }

  static Future<void> markAsRead(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_key) ?? [];
    
    final updatedList = list.map((item) {
      final map = jsonDecode(item);
      if (map['id'] == id) {
        map['is_read'] = true;
      }
      return jsonEncode(map);
    }).toList();
    
    await prefs.setStringList(_key, updatedList);
  }

  static Future<int> getUnreadCount() async {
    final all = await getAll();
    return all.where((n) => !n.isRead).length;
  }

  static Future<void> saveUnique(String title, String message) async {
    final all = await getAll();
    final exists = all.any((n) => n.title == title && n.message == message && !n.isRead);
    if (!exists) {
      await save(title, message);
    }
  }

  static Future<void> delete(int id) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Try to delete from local list
    final List<String> list = prefs.getStringList(_key) ?? [];
    final updatedList = list.where((item) {
      final map = jsonDecode(item);
      return map['id'] != id;
    }).toList();
    await prefs.setStringList(_key, updatedList);
    
    // 2. Also add to "hidden server IDs" list in case it's a server notif
    final hiddenList = prefs.getStringList('hidden_server_notifications') ?? [];
    if (!hiddenList.contains(id.toString())) {
      hiddenList.add(id.toString());
      await prefs.setStringList('hidden_server_notifications', hiddenList);
    }
    
    print("🗑️ LocalStorage: Deleted/Hidden notification $id");
  }

  static Future<List<int>> getHiddenServerIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('hidden_server_notifications') ?? [];
    return list.map((e) => int.parse(e)).toList();
  }

  static Future<void> clearShippingAddressNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear ALL local notifications to ensure shipping address ones are gone
    await prefs.remove(_key);
    print('🧹 Cleared all local notifications');
  }
}
