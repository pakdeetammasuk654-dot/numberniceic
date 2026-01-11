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

  Future<void> init() async {
    print('🔔 NotificationService: init() called. isInitialized: $_isInitialized');
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
        final LOCATION_NAME = 'Asia/Bangkok';
        tz.setLocalLocation(tz.getLocation(LOCATION_NAME));
    } catch(e) {
        print("Timezone error: $e");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_lotus_notification');

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
        print("🔔 Notification Tapped (Local): ${details.payload}");
        if (details.payload != null) {
          try {
            final dynamic parsed = jsonDecode(details.payload!);
            if (parsed is Map<String, dynamic>) {
               // Convert all values to string to match RemoteMessage.data type
               final Map<String, dynamic> dataMap = parsed;
               final Map<String, String> stringData = dataMap.map((key, value) => MapEntry(key, value.toString()));
               
               // Create a pseudo RemoteMessage to feed into the same stream
               final message = RemoteMessage(data: stringData);
               _messageStreamController.add(message);
            }
          } catch (e) {
            print("❌ Payload parse error: $e");
          }
        }
      },
    );
    
    print('🔔 NotificationService: Calling _setupFCM()...');
    await _setupFCM();
    await _setupBackgroundHandlers();

    _isInitialized = true;
    print('🔔 NotificationService: init() completed.');
  }

  Future<void> _setupFCM() async {
    print('🔔 NotificationService: _setupFCM() started.');
    try {
        final messaging = FirebaseMessaging.instance;
        
        // Request Permission
        print('🔔 NotificationService: Requesting permission...');
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        print('🔔 NotificationService: Permission status: ${settings.authorizationStatus}');
    
        if (settings.authorizationStatus == AuthorizationStatus.authorized || settings.authorizationStatus == AuthorizationStatus.provisional) {
           print('✅ FCM Authorization Granted');
           
           // Get Token
           try {
             if (defaultTargetPlatform == TargetPlatform.iOS) {
               String? apnsToken = await messaging.getAPNSToken();
               int retry = 0;
               while (apnsToken == null && retry < 10) {
                 print("⚠️ APNS Token is null. Waiting for it... (Attempt ${retry + 1}/10)");
                 await Future<void>.delayed(const Duration(seconds: 2));
                 apnsToken = await messaging.getAPNSToken();
                 retry++;
               }
               
               if (apnsToken != null) {
                 print("🍏 APNS Token: $apnsToken");
               } else {
                 print("❌ Timed out waiting for APNS Token.");
                 // Should we return or try getToken anyway? getToken will fail but let's try.
               }
             }

             String? token = await messaging.getToken();
             print("📣 FCM Token: $token"); 
             if (token != null) {
                print("🔔 Calling ApiService.saveDeviceToken...");
                await ApiService.saveDeviceToken(token);
                print("🔔 ApiService.saveDeviceToken returned.");
             } else {
                print("⚠️ FCM Token is NULL");
             }
           } catch(e) { print('❌ FCM GetToken Error: $e'); }
           
           // --- SETUP ANDROID CHANNEL ---
           try {
             const AndroidNotificationChannel channel = AndroidNotificationChannel(
               'high_importance_channel', // id
               'High Importance Notifications', // title
               description: 'This channel is used for important notifications.', // description
               importance: Importance.max,
             );

             final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
             await flutterLocalNotificationsPlugin
                 .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                 ?.createNotificationChannel(channel);
                 
             print("✅ Android Notification Channel Setup Complete");
           } catch (e) {
             print("❌ Error Setting up Android Channel: $e");
           }

           // --- CRITICAL: Set Foreground Presentation Options ---
           await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
             alert: true, 
             badge: true,
             sound: true,
           );
           print("✅ Foreground Presentation Options Set");
           // ---------------------------------------------------
           
           FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
               try {
                   print("=================== FCM MESSAGE RECEIVED (FOREGROUND) ===================");
                   print("📩 Notification Title: ${message.notification?.title}");
                   print("📩 Notification Body: ${message.notification?.body}");
                   print("📩 Data Payload: ${message.data}");
                   
                   if (message.notification != null) {
                      print("🔔 [DEBUG] Showing local notification...");
                      showNotification(
                          message.hashCode,
                          message.notification!.title ?? 'NumberNice',
                          message.notification!.body ?? '',
                          data: message.data,
                      );
                      
                      print("🔔 [DEBUG] Saving to local storage...");
                      await LocalNotificationStorage.save(
                        message.notification!.title ?? 'NumberNice',
                        message.notification!.body ?? '',
                      );
                      print("✅ [DEBUG] Saved to local storage.");

                      // Trigger Dashboard Refresh
                      print("🔔 [DEBUG] Updating ApiService.unreadNotificationCount...");
                      print("   - Current Value: ${ApiService.unreadNotificationCount.value}");
                      
                      final newVal = ApiService.unreadNotificationCount.value + 1;
                      ApiService.unreadNotificationCount.value = newVal;
                      
                      print("   - New Value: ${ApiService.unreadNotificationCount.value} (Should be $newVal)");
                      print("🔔 IMMEDIATE UPDATE: Incrementing unread count to $newVal");
                      
                      print("🔔 [DEBUG] Updating dashboardRefreshSignal...");
                      ApiService.dashboardRefreshSignal.value++;
                   }
                   
                   // Broadcast the message to any listeners
                   _messageStreamController.add(message);
                   print("=========================================================================");
               } catch (e, stackTrace) {
                   print("❌❌ ERROR in FCM Handler: $e");
                   print(stackTrace);
               }
           });
           print('🔔 FCM Listeners setup completed.');

        } else {
          print('❌ FCM Permission Declined');
        }
    } catch (e) {
        print('❌ _setupFCM Critical Error: $e');
    }
  }

  Future<void> _setupBackgroundHandlers() async {
      // Background Tap Handling
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          print("📩 Notification Tapped (Background): ${message.notification?.title}");
          _messageStreamController.add(message);
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

  // Helper to show immediate notification (reusing local plugin)
  Future<void> showNotification(int id, String title, String body, {Map<String, dynamic>? data}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'general_channel', 'General Notifications',
            channelDescription: 'General app notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@drawable/ic_lotus_notification',
            color: Color(0xFFFFA000)); // Gold color
            
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  Future<bool> requestPermissions() async {
    // Android 13+ notification permission
    PermissionStatus status = await Permission.notification.status;
    if (status.isDenied) {
      status = await Permission.notification.request();
    }
    
    if (status.isPermanentlyDenied) {
      // User needs to go to settings
      return false;
    }

    // Android 12+ exact alarm permission (for precise Buddhist day notifications)
    try {
      final scheduleStatus = await Permission.scheduleExactAlarm.status;
      print('🔔 Exact Alarm Permission Status: $scheduleStatus');
      
      if (scheduleStatus.isDenied) {
        print('🔔 Requesting Exact Alarm Permission...');
        final result = await Permission.scheduleExactAlarm.request();
        print('🔔 Exact Alarm Permission Result: $result');
        
        if (result.isPermanentlyDenied) {
          print('⚠️ Exact Alarm Permission permanently denied - notifications may not be precise');
        }
      }
    } catch (e) {
      print('⚠️ Exact Alarm Permission not available on this device: $e');
    }

    // iOS handles via flutter_local_notifications
    final bool? result = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        
    return status.isGranted || (result ?? false);
  }

  Future<void> scheduleBuddhistDayNotifications(List<dynamic> days) async {
    await cancelAll(); // Clear old ones first

    // Load Buddhist days from local JSON file
    List<dynamic> buddhistDays = [];
    try {
      print('📂 Loading Buddhist days from local JSON...');
      final String jsonString = await rootBundle.loadString('assets/buddhist_days.json');
      buddhistDays = json.decode(jsonString) as List<dynamic>;
      print('✅ Loaded ${buddhistDays.length} Buddhist days from local file');
    } catch (e) {
      print('❌ Error loading local Buddhist days: $e');
      print('⚠️ Falling back to API data...');
      buddhistDays = days; // Fallback to API data if local file fails
    }

    int id = 1000; // Start with ID 1000 to avoid conflict
    final now = DateTime.now();
    
    // Sort and Filter: Only future days, and only up to 50 upcoming ones to avoid OS limits
    List<dynamic> upcomingDays = buddhistDays.where((d) {
      final date = DateTime.parse(d['date']);
      return date.isAfter(now.subtract(const Duration(hours: 24))); // Include today
    }).toList();
    
    upcomingDays.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
    
    if (upcomingDays.length > 50) {
      upcomingDays = upcomingDays.sublist(0, 50);
    }

    print("📅 Scheduling ${upcomingDays.length} Buddhist Day notifications. Current time: $now");

    for (var day in upcomingDays) {
      // day = { "id": 1, "date": "2024-05-22T00:00:00Z" }
      try {
        DateTime date = DateTime.parse(day['date']); // Parse as Local or UTC? Go sends UTC likely.
        
        // Buddhist Day starts at MIDNIGHT (00:00), not 8 AM
        final scheduledDate = DateTime(date.year, date.month, date.day, 0, 0, 0);
        
        print("📅 Processing Buddhist Day: ${scheduledDate.toString()}");

        // If it's in the past:
        if (scheduledDate.isBefore(now)) {
           // If it is effectively "today" (same year, month, day), but we missed midnight, 
           // and the day hasn't ended yet, show it immediately.
           if (scheduledDate.year == now.year && scheduledDate.month == now.month && scheduledDate.day == now.day) {
               print("🔔 IMMEDIATE: Today is Buddhist Day! Showing notification now.");
               String title = (day['title'] != null && day['title'].toString().isNotEmpty) ? day['title'] : "วันนี้วันพระ";
               String message = (day['message'] != null && day['message'].toString().isNotEmpty) ? day['message'] : "อย่าลืมทำบุญและรักษาศีลเพื่อความเป็นสิริมงคล";
               await _showImmediate(id++, title, message);
           }
           continue; 
        }

        // Schedule notification for Buddhist Day (MIDNIGHT 00:00)
        print("⏰ Scheduling Buddhist Day notification for midnight: ${scheduledDate.toString()}");
        String title = (day['title'] != null && day['title'].toString().isNotEmpty) ? day['title'] : "วันนี้วันพระ";
        String message = (day['message'] != null && day['message'].toString().isNotEmpty) ? day['message'] : "อย่าลืมทำบุญและรักษาศีลเพื่อความเป็นสิริมงคล";
        await _scheduleOne(id++, title, message, scheduledDate);
        
        // Schedule notification for day BEFORE Buddhist Day (8:00 PM)
        final dayBefore = scheduledDate.subtract(const Duration(days: 1));
        final dayBeforeEvening = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 20, 0, 0);
        
        // Check if TODAY is the day before Buddhist Day
        final isToday = dayBefore.year == now.year && dayBefore.month == now.month && dayBefore.day == now.day;
        
        print("📊 Day before date: ${dayBefore.year}-${dayBefore.month}-${dayBefore.day}");
        print("📊 Today's date: ${now.year}-${now.month}-${now.day}");
        print("📊 Is today the day before? $isToday");
        print("📊 Day before evening time: ${dayBeforeEvening.toString()}");
        
        if (isToday) {
          // Today IS the day before Buddhist Day
          print("🔔 IMMEDIATE: Today is day before Buddhist Day! Showing notification now.");
          String beforeTitle = "พรุ่งนี้วันพระ";
          if (title.contains("วันนี้")) {
            beforeTitle = title.replaceFirst("วันนี้", "พรุ่งนี้");
          }
          await _showImmediate(id++, beforeTitle, message);
          
          // Also schedule for 8 PM if not yet passed
          if (dayBeforeEvening.isAfter(now)) {
            print("⏰ Also scheduling for 8 PM today: ${dayBeforeEvening.toString()}");
            await _scheduleOne(id++, "$beforeTitle (เตือนอีกครั้ง)", message, dayBeforeEvening);
          }
        } else if (dayBeforeEvening.isAfter(now)) {
          // Future day - schedule normally
          print("⏰ Scheduling day-before notification for: ${dayBeforeEvening.toString()}");
          String beforeTitle = "พรุ่งนี้วันพระ";
          if (title.contains("วันนี้")) {
            beforeTitle = title.replaceFirst("วันนี้", "พรุ่งนี้");
          }
          await _scheduleOne(id++, beforeTitle, message, dayBeforeEvening);
        } else {
          print("⏭️ Skipping day-before notification (already past)");
        }
        
      } catch (e) {
        print("❌ Error scheduling for day $day: $e");
      }
    }
    
    print("✅ Finished scheduling all Buddhist Day notifications");
  }

  Future<void> _scheduleOne(int id, String title, String body, DateTime scheduledDate) async {
     await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'buddhist_day_channel',
            'Buddhist Day Notifications',
            channelDescription: 'Notifications for Buddhist Holy Days',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFFFFEB3B), // Vibrant Yellow (Material Amber/Yellow)
            icon: '@drawable/ic_lotus_notification', // Small icon: Lotus silhouette XML
            largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_lotus_yellow'), // Large icon: Beautiful Yellow Lotus PNG
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
  }

  Future<void> _showImmediate(int id, String title, String body) async {
    print("🔔 _showImmediate called: id=$id, title=$title");
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('buddhist_day_channel', 'Buddhist Day Notifications',
            channelDescription: 'Notifications for Buddhist Holy Days',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            icon: '@drawable/ic_lotus_notification', // Small icon: Lotus silhouette XML
            largeIcon: DrawableResourceAndroidBitmap('@drawable/ic_lotus_yellow'), // Large icon: Beautiful Yellow Lotus PNG
            playSound: true,
            enableVibration: true,
            color: Color(0xFFFFEB3B)); // Vibrant Yellow
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    try {
      await flutterLocalNotificationsPlugin.show(
          id, title, body, platformChannelSpecifics);
      print("✅ Notification shown successfully: $title");
      
      // Save notification to in-app bell list (Server & Local Fallback)
      print("🔔 Saving notification to in-app bell list...");
      await LocalNotificationStorage.save(title, body); // Save locally first
      await ApiService.createNotification(title, body); // Then try server
      print("✅ Notification saved successfully (Local + attempted Server)");
    } catch (e) {
      print("❌ Error showing notification: $e");
    }
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
