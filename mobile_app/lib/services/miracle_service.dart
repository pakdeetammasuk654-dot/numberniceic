import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MiracleService {
  static final MiracleService _instance = MiracleService._internal();
  factory MiracleService() => _instance;
  MiracleService._internal();

  Map<String, dynamic>? _data;
  final String _prefKeyBirthDay = 'miracle_user_birth_day';

  Future<void> init() async {
    if (_data != null) return;
    try {
      final jsonString = await rootBundle.loadString('assets/miracle_data.json');
      _data = json.decode(jsonString);
    } catch (e) {
      print("Error loading miracle data: $e");
    }
  }

  Future<String?> getUserBirthDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyBirthDay);
  }

  Future<void> saveUserBirthDay(String day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyBirthDay, day);
  }

  // Get current day key (sunday, monday, etc.) or for a specific date
  String getDayKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    // Weekday: 1=Mon, ..., 7=Sun
    switch (d.weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday'; 
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'sunday';
    }
  }
  
  String getThaiDayName(String key) {
    if (_data == null) return key;
    return _data!['days_translation'][key] ?? key;
  }

  Map<String, dynamic>? getDailyLuck(String birthDay) {
    return _calculateLuckForDay(birthDay, getDayKey());
  }

  Map<String, dynamic>? _calculateLuckForDay(String birthDay, String dayKey) {
    if (_data == null) return null;
    
    // Structure: data -> birthDay -> activity -> currentDay -> { is_good, description }
    final birthData = _data!['data'][birthDay];
    if (birthData == null) return null;

    final Map<String, dynamic> activities = {};
    final List<String> goodActs = [];
    final List<String> badActs = [];
    
    // Activities: "ตัดผม", "สระผม", "ตัดเล็บ", "ผ้าใหม่"
    birthData.forEach((activityName, activityData) {
      if (activityData[dayKey] != null) {
        final act = activityData[dayKey];
        activities[activityName] = act;
        
        if (act['is_good'] == true) {
           goodActs.add(activityName);
        } else {
           badActs.add(activityName);
        }
      }
    });

    return {
      'current_day': dayKey,
      'activities': activities,
      'good_list': goodActs,
      'bad_list': badActs
    };
  }
  
  bool get isDataLoaded => _data != null;

  Map<String, dynamic>? getSpecificLuck(String birthDay, String activity, String dayKey) {
     return _data?['data']?[birthDay]?[activity]?[dayKey];
  }

  List<Map<String, dynamic>> generateWeeklyNotifications(String birthDay) {
     List<Map<String, dynamic>> notifs = [];
     final now = DateTime.now();
          // Schedule for next 7 days (including today for history)
     for (int i = 0; i <= 7; i++) {
        final date = now.add(Duration(days: i));
        // Target 07:00 AM
        final scheduleTime = DateTime(date.year, date.month, date.day, 7, 0, 0); 
        
        final dayKey = getDayKey(date);
        final thaiDay = getThaiDayName(dayKey);
        
        final results = _calculateLuckForDay(birthDay, dayKey);
        if (results == null) continue;
        
        final goodList = results['good_list'] as List<String>;
        
        String msg = '';
        if (goodList.isNotEmpty) {
           msg = 'วันนี้ฤกษ์ดี: ${goodList.join(', ')} ช่วยเสริมสิริมงคล';
        } else {
           msg = 'วันนี้วันพระธรรมดา ทำจิตใจให้ผ่องใส';
        }
        
        // Add emoji based on day
        String emoji = '🌞';
        switch(dayKey) {
           case 'monday': emoji = '💛'; break;
           case 'tuesday': emoji = '🩷'; break;
           case 'wednesday': emoji = '💚'; break;
           case 'thursday': emoji = '🧡'; break;
           case 'friday': emoji = '💙'; break;
           case 'saturday': emoji = '💜'; break;
           case 'sunday': emoji = '❤️'; break;
        }
        
        notifs.add({
           'id': 2000 + i, // Unique ID range for Miracles
           'title': 'อรุณสวัสดิ์$thaiDay $emoji',
           'body': msg,
           'date': scheduleTime,
           'type': 'daily_miracle' 
        });
     }
     return notifs;
  }
}
