import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'viewmodels/analyzer_view_model.dart';
import 'screens/landing_page.dart';
import 'screens/main_tab_page.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart'; // Ensure correct import
import 'package:firebase_core/firebase_core.dart'; // NEW
import 'package:firebase_messaging/firebase_messaging.dart'; // NEW

// Background Handler must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
     await Firebase.initializeApp();
     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
     print("✅ Firebase Initialized");
  } catch (e) {
     print("❌ Firebase Init Error: $e");
  }

  // Lock Orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Date Formatting
  await initializeDateFormatting('th_TH', null);

  // Initialize Notification Service
  // Note: We call init() in DashboardPage/MainPage usually, 
  // but calling basic init here is fine too or handled later.
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnalyzerViewModel()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NumberNiceIC Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: false,
        // Apply Kanit font globally
        textTheme: GoogleFonts.kanitTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      // Set Main Tab Page as the home
      home: const MainTabPage(),
    );
  }
}
