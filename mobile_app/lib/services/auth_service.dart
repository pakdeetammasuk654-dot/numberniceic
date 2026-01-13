
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart' as fb_auth;
import 'package:flutter_line_sdk/flutter_line_sdk.dart' as line_sdk;
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/social_auth_config.dart'; // Import config
import 'api_service.dart';
import 'notification_service.dart';
import 'local_notification_storage.dart';

class AuthService {
  static const String keyToken = 'jwt_token';
  static const String keyUsername = 'auth_username';
  static const String keyIsVip = 'auth_is_vip';
  static const String keyVipExpiryText = 'auth_vip_expiry_text';
  static const String keyEmail = 'auth_email';
  static const String keyAvatarUrl = 'auth_avatar_url';
  static const String keyAssignedColors = 'auth_assigned_colors';
  static const String keyPendingPurchase = 'auth_pending_purchase';

  // Google Sign-In Instance
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ===== SOCIAL LOGIN METHODS =====

  /// Login with Google
  static Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'message': 'ยกเลิกการเข้าสู่ระบบ'};
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      return await _authenticateWithBackend(
        provider: 'google',
        providerToken: googleAuth.idToken ?? googleAuth.accessToken ?? '',
        accessToken: googleAuth.accessToken,
        email: googleUser.email,
        name: googleUser.displayName ?? '',
        avatarUrl: googleUser.photoUrl ?? '',
      );
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  /// Login with Facebook
  static Future<Map<String, dynamic>> loginWithFacebook() async {
    try {
      final fb_auth.LoginResult result = await fb_auth.FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != fb_auth.LoginStatus.success) {
        return {'success': false, 'message': 'ยกเลิกการเข้าสู่ระบบ'};
      }

      final userData = await fb_auth.FacebookAuth.instance.getUserData();
      
      return await _authenticateWithBackend(
        provider: 'facebook',
        providerToken: result.accessToken!.token,
        email: userData['email'] ?? '',
        name: userData['name'] ?? '',
        avatarUrl: userData['picture']?['data']?['url'] ?? '',
      );
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  /// Login with LINE - Smart method selection based on Android version
  static Future<Map<String, dynamic>> loginWithLine() async {
    try {
      print("Starting LINE Login (Smart Selection)...");
      
      // Check Android version (only on Android)
      if (Platform.isAndroid) {
        // Get Android SDK version
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        print("📱 Android SDK Version: $sdkInt");
        
        // Use WebView for Android 9 and below (API 28-)
        if (sdkInt < 29) {
          print("⚠️ Android version < 10, using WebView for compatibility");
          // Return a special code to indicate WebView should be used
          return {'success': false, 'use_webview': true, 'message': 'Please use WebView login'};
        }
        
        print("✅ Android 10+, using Native SDK");
      }
      
      // Use LINE SDK - it will automatically try native app first, then fallback to WebView
      final result = await line_sdk.LineSDK.instance.login(
        scopes: ["profile", "openid", "email"],
      );
      
      if (result.userProfile == null) {
        return {'success': false, 'message': 'ไม่สามารถดึงข้อมูลผู้ใช้ได้'};
      }

      print("✅ LINE Login Success: ${result.userProfile!.displayName}");

      return await _authenticateWithBackend(
        provider: 'line',
        providerToken: result.accessToken.value,
        email: '',
        name: result.userProfile!.displayName,
        avatarUrl: result.userProfile!.pictureUrl ?? '',
      );
    } on PlatformException catch (e) {
      print('❌ LINE Login Platform Exception: ${e.code} - ${e.message}');
      
      // Handle user cancellation gracefully
      if (e.code == 'CANCEL') {
        return {'success': false, 'message': 'ยกเลิกการเข้าสู่ระบบ'};
      }
      
      return {'success': false, 'message': 'LINE Error (${e.code}): ${e.message}'};
    } catch (e) {
      print('❌ LINE Login Error: $e');
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  // ===== DIRECT LINE LOGIN (MANUAL OAUTH) =====
  
  /// Exchange Authorization Code for Token and Login
  static Future<Map<String, dynamic>> handleLineDirectLogin(String code) async {
    try {
      print("💱 Exchanging LINE Code for Token...");
      
      // 1. Exchange Code for Token
      final tokenUrl = Uri.parse('https://api.line.me/oauth2/v2.1/token');
      final tokenResponse = await http.post(
        tokenUrl,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': SocialAuthConfig.lineRedirectUri,
          'client_id': SocialAuthConfig.lineChannelId,
          'client_secret': SocialAuthConfig.lineChannelSecret,
        },
      );

      print('LINE Token Response: ${tokenResponse.body}');

      if (tokenResponse.statusCode != 200) {
        return {'success': false, 'message': 'LINE Token Error: ${tokenResponse.body}'};
      }

      final tokenData = jsonDecode(tokenResponse.body);
      final accessToken = tokenData['access_token'];
      
      // 2. Get User Profile
      final profileUrl = Uri.parse('https://api.line.me/v2/profile');
      final profileResponse = await http.get(
        profileUrl,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      
      print('LINE Profile Response: ${profileResponse.body}');

      if (profileResponse.statusCode != 200) {
        return {'success': false, 'message': 'LINE Profile Error: ${profileResponse.body}'};
      }

      final profileData = jsonDecode(profileResponse.body);
      
      // 3. Authenticate with Our Backend
      return await _authenticateWithBackend(
        provider: 'line',
        providerToken: accessToken,
        email: '', 
        name: profileData['displayName'],
        avatarUrl: profileData['pictureUrl'] ?? '',
        accessToken: accessToken,
      );

    } catch (e) {
      print('Direct Line Login Error: $e');
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: $e'};
    }
  }

  /// Authenticate with backend using social provider data
  static Future<Map<String, dynamic>> _authenticateWithBackend({
    required String provider,
    required String providerToken,
    String? accessToken,
    required String email,
    required String name,
    required String avatarUrl,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/auth/social');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': provider,
          'provider_token': providerToken,
          'access_token': accessToken,
          'email': email,
          'name': name,
          'avatar_url': avatarUrl,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await syncAuthData(data);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'เข้าสู่ระบบไม่สำเร็จ'};
      }
    } catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการเชื่อมต่อ: $e'};
    }
  }
  
  // ... Legacy methods ... (same as before)
  @deprecated
  static Future<Map<String, dynamic>> login(String username, String password) async {
    return {'success': false, 'message': 'Legacy login deprecated'};
  }
  
  @deprecated
  static Future<Map<String, dynamic>> register(String username, String password, String email, String tel) async {
    return {'success': false, 'message': 'Legacy register deprecated'};
  }

  // ===== UTILITY METHODS =====

  static Future<void> logout() async {
    // 1. Clear Notifications (System & History)
    try {
      await NotificationService().cancelAll();
      await LocalNotificationStorage.clearAll(); // Clear History List
      await FirebaseMessaging.instance.deleteToken();
      print("✅ Notification Token Deleted & History Cleared");
    } catch (e) {
      print("Logout Cleanup Error: $e");
    }

    // 2. Clear Social Auth
    try {
      try { await _googleSignIn.signOut(); } catch (e) { print("Google SignOut Error: $e"); }
      try { await fb_auth.FacebookAuth.instance.logOut(); } catch (e) { print("Facebook SignOut Error: $e"); }
      try { 
        // Only attempt line logout if we suspect it's available, otherwise skip to prevent crashes
        await line_sdk.LineSDK.instance.logout(); 
      } catch (e) { print("Line SignOut Error: $e"); }
    } catch (e) {
      print("Global Logout Error: $e");
    }

    // 3. Clear Local User Data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyToken);
    await prefs.remove(keyUsername);
    await prefs.remove(keyIsVip);
    await prefs.remove(keyVipExpiryText);
    await prefs.remove(keyEmail);
    await prefs.remove(keyAvatarUrl);
    await prefs.remove(keyAssignedColors);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(keyToken);
  }

  static Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString(keyUsername),
      'email': prefs.getString(keyEmail),
      'avatar_url': prefs.getString(keyAvatarUrl),
      'is_vip': prefs.getBool(keyIsVip) ?? false,
      'vip_expiry_text': prefs.getString(keyVipExpiryText),
      'assigned_colors': prefs.getStringList(keyAssignedColors) ?? [],
    };
  }

  /// Fetches latest user data from server and updates local storage
  static Future<void> refreshUserProfile() async {
    try {
      final data = await ApiService.getDashboard();
      await syncAuthData(data);
    } catch (e) {
      print("Failed to refresh user profile: $e");
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyToken);
  }

  static Future<List<String>> getAssignedColors() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyAssignedColors) ?? [];
  }

  static Future<void> syncAuthData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (data['token'] != null) await prefs.setString(keyToken, data['token']);
    if (data['username'] != null) await prefs.setString(keyUsername, data['username']);
    if (data['email'] != null) await prefs.setString(keyEmail, data['email']);
    if (data['avatar_url'] != null) await prefs.setString(keyAvatarUrl, data['avatar_url']);
    if (data['is_vip'] != null) await prefs.setBool(keyIsVip, data['is_vip']);
    if (data['vip_expiry_text'] != null) await prefs.setString(keyVipExpiryText, data['vip_expiry_text']);
    
    if (data['assigned_colors'] != null) {
      if (data['assigned_colors'] is List) {
        final List<String> colors = List<String>.from(data['assigned_colors']);
        await prefs.setStringList(keyAssignedColors, colors);
      }
    }
  }

  // Pending Purchase Management
  static Future<void> setPendingPurchase(Map<String, dynamic>? productData) async {
    final prefs = await SharedPreferences.getInstance();
    if (productData == null) {
      await prefs.remove(keyPendingPurchase);
    } else {
      await prefs.setString(keyPendingPurchase, jsonEncode(productData));
    }
  }

  static Future<Map<String, dynamic>?> getPendingPurchase() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(keyPendingPurchase);
    if (data == null) return null;
    try {
      return jsonDecode(data);
    } catch (e) {
      return null;
    }
  }
}
