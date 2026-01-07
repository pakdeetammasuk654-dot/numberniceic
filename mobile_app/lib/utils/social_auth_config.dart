import 'package:flutter_line_sdk/flutter_line_sdk.dart';

class SocialAuthConfig {
  // LINE Configuration
  static const String lineChannelId = '2008834631'; 
  static const String lineChannelSecret = '63b01d23eeacdd93f3d517f83df4dccc'; // ⚠️ PLEASE UPDATE THIS SECRET IF IT CHANGED!
  static const String lineRedirectUri = 'https://www.xn--b3cu8e7ah6h.com/auth/line/callback';
  
  // Initialize LINE SDK
  static Future<void> initializeLineSDK() async {
    try {
      await LineSDK.instance.setup(lineChannelId);
      print('✅ LINE SDK Initialized Successfully');
    } catch (e) {
      print('LINE SDK initialization error: $e');
    }
  }
  
  // Google Sign-In is auto-configured via google-services.json (Android) and GoogleService-Info.plist (iOS)
  // Facebook is configured via AndroidManifest.xml and Info.plist
}
