import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const String keyToken = 'jwt_token';
  static const String keyUsername = 'auth_username';
  static const String keyIsVip = 'auth_is_vip';
  static const String keyVipExpiryText = 'auth_vip_expiry_text';

  // Login
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Save Token & Basic Info
        await _saveAuthData(data);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Register
  static Future<Map<String, dynamic>> register(String username, String password, String email, String tel) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'email': email,
          'tel': tel,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyToken);
    await prefs.remove(keyUsername);
    await prefs.remove(keyIsVip);
    await prefs.remove(keyVipExpiryText);
  }

  // Check if logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(keyToken);
  }

  // Get current user info
  static Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString(keyUsername),
      'is_vip': prefs.getBool(keyIsVip) ?? false,
      'vip_expiry_text': prefs.getString(keyVipExpiryText),
    };
  }

  // Get Token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyToken);
  }

  // Helper to save data
  static Future<void> _saveAuthData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['token'] != null) {
      await prefs.setString(keyToken, data['token']);
    }
    if (data['username'] != null) {
      await prefs.setString(keyUsername, data['username']);
    }
    if (data['is_vip'] != null) {
      await prefs.setBool(keyIsVip, data['is_vip']);
    }
    if (data['vip_expiry_text'] != null) {
      await prefs.setString(keyVipExpiryText, data['vip_expiry_text']);
    }
  }
}
