import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async'; // For StreamController
import 'dart:convert'; // For JSON decoding
import 'api_service.dart';
import 'local_notification_storage.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  
  // Stream to allow UI to listen for incoming messages (e.g. to show bottom sheets)
  final StreamController<RemoteMessage> _messageStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messageStream => _messageStreamController.stream;

  // Debug Token Log
  static final ValueNotifier<String> debugTokenLog = ValueNotifier<String>("Initializing...");

  Future<void> init() async {
    // 1. If already initialized, retry saving token to server (Just to be sure)
    if (_isInitialized) {
       try {
         String? t = await FirebaseMessaging.instance.getToken();
         if (t != null) {
            await ApiService.saveDeviceToken(t);
         }
       } catch(_) {}
       return;
    }
    
    // 2. Start First Init
    _isInitialized = true;

    try {
      // 1. Setup Local Notifications (PRIORITY #1)
      await Future.delayed(const Duration(milliseconds: 500));
      
      // USE GUARANTEED DRAWABLE 'notification_icon'
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('notification_icon');

      final DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          if (details.payload != null && details.payload!.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(details.payload!);
              _messageStreamController.add(RemoteMessage(
                data: {...data, 'tapped': 'true'},
              ));
            } catch (e) {
              print("❌ Error parsing: $e");
            }
          }
        },
      );

      // 2. Setup FCM (PRIORITY #2)
      await _setupFCM();
      await _setupBackgroundHandlers();

      // 3. Setup Timezone (Non-Critical)
      // debugTokenLog.value = "Init: Timezone Setup..."; // Don't overwrite Token!
      try {
        tz.initializeTimeZones();
        try {
            final LOCATION_NAME = 'Asia/Bangkok';
            tz.setLocalLocation(tz.getLocation(LOCATION_NAME));
        } catch(e) {
            print("Timezone Location Error: $e");
        }
      } catch (e) {
        print("Timezone Init Error (Ignored): $e");
      }
      
      // Final Check (Silent)
      debugTokenLog.value = ""; // Clear log on success

    } catch (e) {
      print("❌ CRITICAL INIT ERROR: $e");
      debugTokenLog.value = "Init CRASH: $e";
    }
  }

  Future<void> _setupFCM() async {
    print('🔔 NotificationService: _setupFCM() started.');
    try {
      final messaging = FirebaseMessaging.instance;
      
      // 1. Request Permission (For UI display)
      print('🔔 NotificationService: Requesting permission...');
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('🔔 NotificationService: Permission status: ${settings.authorizationStatus}');

      // 2. ALWAYS GET TOKEN (Supports guest notifications)
      try {
        String? token = await messaging.getToken();
        print("📣 FCM Token obtained: $token"); 
        if (token != null) {
          await ApiService.saveDeviceToken(token);
          print("✅ FCM Token registered with server.");
        }
      } catch(e) { 
        print('❌ FCM GetToken Error: $e'); 
      }

      // 3. Setup Android Channel
      try {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'numbernice_channel_v1',
          'NumberNiceIC Notifications',
          description: 'แจ้งเตือนข่าวสารและสีกระเป๋า',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
            
        print("✅ Android Notification Channel Setup Complete");
      } catch (e) {
        print("❌ Error Setting up Android Channel: $e");
      }

      // 4. Set Foreground Presentation Options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, 
        badge: true,
        sound: true,
      );

      // 5. Listen for Foreground Messages
      // 5. Listen for Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        try {
          
          String title = message.data['title'] ?? message.notification?.title ?? 'การแจ้งเตือน';
          String body = message.data['body'] ?? message.data['message'] ?? message.notification?.body ?? '';
          
          if (title.isNotEmpty || body.isNotEmpty) {
             await showNotification(message.hashCode, title, body, data: message.data);
             
             await LocalNotificationStorage.save(title, body, data: message.data);
             ApiService.dashboardRefreshSignal.value++;
             _messageStreamController.add(message);
          }
        } catch (e) {
          print("❌ ERROR in FCM Handler: $e");
        }
      });

      print('🔔 FCM Listeners setup completed.');
    } catch (e) {
      print('❌ _setupFCM Critical Error: $e');
    }
  }

  Future<void> _setupBackgroundHandlers() async {
    // Background Tap Handling
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📩 Notification Tapped (Background): ${message.notification?.title}");
      // Inject tapped flag
      final Map<String, dynamic> data = Map<String, dynamic>.from(message.data);
      data['tapped'] = 'true';
      
      _messageStreamController.add(RemoteMessage(
        data: data,
        notification: message.notification,
      ));
    });

    // Terminated State Handling
    try {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print("📩 Notification Tapped (Terminated): ${initialMessage.notification?.title}");
        _messageStreamController.add(initialMessage);
      }
    } catch (e) {
      print("Error getting initial message: $e");
    }
  }

  Future<bool> requestPermissions() async {
    print('🔔 NotificationService: requestPermissions() called.');
    final status = await Permission.notification.request();
    print('🔔 Notification Permission Status: $status');
    
    if (status.isPermanentlyDenied) {
      return false;
    }

    // Android 12+ exact alarm permission
    try {
      final scheduleStatus = await Permission.scheduleExactAlarm.status;
      if (scheduleStatus.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (_) {}

    final bool? result = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
        
    return status.isGranted || (result ?? false);
  }

  Future<void> showNotification(int id, String title, String body, {Map<String, dynamic>? data}) async {
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'numbernice_channel_v1',
          'NumberNiceIC Notifications',
          channelDescription: 'แจ้งเตือนข่าวสารและสีกระเป๋า',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'notification_icon',
          color: const Color(0xFFFFEB3B),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  Future<void> scheduleBuddhistDayNotifications(List<dynamic> days) async {
    await cancelAll();

    List<dynamic> buddhistDays = [];
    try {
      final String jsonString = await rootBundle.loadString('assets/buddhist_days.json');
      buddhistDays = json.decode(jsonString) as List<dynamic>;
    } catch (e) {
      buddhistDays = days;
    }

    int id = 1000;
    final now = DateTime.now();
    
    List<dynamic> upcomingDays = buddhistDays.where((d) => DateTime.parse(d['date']).isAfter(now.subtract(const Duration(hours: 24)))).toList();
    upcomingDays.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    
    if (upcomingDays.length > 50) upcomingDays = upcomingDays.sublist(0, 50);

    for (var day in upcomingDays) {
      try {
        DateTime date = DateTime.parse(day['date']);
        final scheduledDate = DateTime(date.year, date.month, date.day, 0, 0, 0);
        
        String title = day['title'] ?? "วันนี้วันพระ";
        String message = day['message'] ?? "อย่าลืมทำบุญและรักษาศีลเพื่อความเป็นสิริมงคล";

        if (scheduledDate.isBefore(now)) {
           if (scheduledDate.year == now.year && scheduledDate.month == now.month && scheduledDate.day == now.day) {
               await _showImmediate(id++, title, message, data: {'type': 'buddhist_day'});
           }
           continue; 
        }

        await _scheduleOne(id++, title, message, scheduledDate, data: {'type': 'buddhist_day'});
        
        // Day before at 8 PM
        final dayBeforeEvening = scheduledDate.subtract(const Duration(hours: 4)); // 00:00 - 4h = 20:00 previous day
        if (dayBeforeEvening.isAfter(now)) {
          await _scheduleOne(id++, title.replaceFirst("วันนี้", "พรุ่งนี้"), message, dayBeforeEvening, data: {'type': 'buddhist_day'});
        } else if (dayBeforeEvening.year == now.year && dayBeforeEvening.month == now.month && dayBeforeEvening.day == now.day) {
           await _showImmediate(id++, title.replaceFirst("วันนี้", "พรุ่งนี้"), message, data: {'type': 'buddhist_day'});
        }
      } catch (_) {}
    }
  }

  Future<void> _scheduleOne(int id, String title, String body, DateTime scheduledDate, {Map<String, String>? data}) async {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id, title, body, tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'numbernice_channel_v1', 'NumberNiceIC Notifications',
            importance: Importance.max, priority: Priority.high,
            icon: 'notification_icon',
            color: const Color(0xFFFFEB3B),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: data != null ? jsonEncode(data) : null,
      );
  }

  Future<void> _showImmediate(int id, String title, String body, {Map<String, String>? data}) async {
    await flutterLocalNotificationsPlugin.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'numbernice_channel_v1', 'NumberNiceIC Notifications',
          importance: Importance.max, priority: Priority.high,
          icon: 'notification_icon',
          color: const Color(0xFFFFEB3B),
        ),
      ),
      payload: data != null ? jsonEncode(data) : null,
    );
    await LocalNotificationStorage.save(title, body, data: data);
    await ApiService.createNotification(title, body);
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
