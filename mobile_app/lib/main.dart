import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'viewmodels/analyzer_view_model.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'utils/social_auth_config.dart';

// Background Handler must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  
  // Manually show notification for Data Messages
  if (message.data.isNotEmpty) {
      final title = message.data['title'] ?? 'การแจ้งเตือน';
      final body = message.data['body'] ?? '';
      
      // We must initialize the service primarily to get the plugin instance ready
      final notificationService = NotificationService();
      // Initialize locally if needed, though showing might just need the plugin.
      // But safe to call init() to setup channels.
      await notificationService.init(); 
      
      await notificationService.showNotification(
        message.hashCode, 
        title, 
        body, 
        data: message.data
      );
  }
}

@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
     await Firebase.initializeApp();
     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
     print("✅ Firebase Initialized");
     
     // Initialize Notification Service (FCM Listeners)
     // REMOVED from main to debug lifecycle issues. Will be called in Dashboard.
     // await NotificationService().init();
     // print("✅ NotificationService Initialized in main()");
  } catch (e) {
     print("❌ Firebase Init Error: $e");
  }

  // Initialize LINE SDK (Prevents crash on logout)
  try {
    await SocialAuthConfig.initializeLineSDK();
  } catch (e) {
    print("❌ LINE SDK Init Error: $e");
  }

  // Lock Orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Date Formatting
  await initializeDateFormatting('th_TH', null);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnalyzerViewModel()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'NumberNiceIC Mobile',
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          // Set Splash Screen as the initial home
          home: const SplashScreen(),
        );
      },
    );
  }
}
