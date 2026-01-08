import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_tab_page.dart';
import 'utils/social_auth_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize LINE SDK in background
  SocialAuthConfig.initializeLineSDK();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
