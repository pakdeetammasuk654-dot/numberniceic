import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/sample_name.dart';
import 'auth_service.dart';

class ApiService {
  static String get baseUrl => 'http://localhost:3000';

  static Future<List<Article>> getArticles() async {
    final url = Uri.parse('$baseUrl/api/articles');
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Article.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load articles');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Article> getArticleBySlug(String slug) async {
    final url = Uri.parse('$baseUrl/api/articles/$slug');
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Article.fromJson(data);
      } else {
        throw Exception('Failed to load article');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    final url = Uri.parse('$baseUrl/api/dashboard');
    debugPrint('🚀 API REQUEST: GET $url (Authenticated)');
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No token found');
      }

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        await AuthService.logout();
        throw Exception('Session expired');
      } else {
        throw Exception('Failed to load dashboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<bool> isBuddhistDayToday() async {
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final url = Uri.parse('$baseUrl/api/buddhist-days/check?date=$dateStr');
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_buddhist_day'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> analyzeName(String name, String day, {bool auspicious = false, bool disableKlakini = false}) async {
    final queryParams = {
      'name': name,
      'day': day,
      'auspicious': auspicious.toString(),
      'disable_klakini': disableKlakini.toString(),
    };
    final url = Uri.parse('$baseUrl/api/analyze').replace(queryParameters: queryParams);
    debugPrint('🚀 API REQUEST: GET $url');
    
    try {
      final token = await AuthService.getToken();
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to analyze name');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> analyzeLinguistically(String name) async {
    final url = Uri.parse('$baseUrl/api/analyze-linguistically?name=$name');
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to analyze name linguistically');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> getUpgradeInfo() async {
    final url = Uri.parse('$baseUrl/api/payment/upgrade');
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('กรุณาเข้าสู่ระบบ');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('ไม่สามารถดึงข้อมูลชำระเงินได้');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<String> checkPaymentStatus(String refNo) async {
    final url = Uri.parse('$baseUrl/api/payment/status/$refNo');
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] ?? 'pending';
      }
      return 'pending';
    } catch (e) {
      return 'pending';
    }
  }

  static Future<String> deleteSavedName(int id) async {
    final url = Uri.parse('$baseUrl/api/saved-names/$id');
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อนดำเนินการ');
      }

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return 'ลบรายชื่อเรียบร้อยแล้ว';
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['error'] ?? 'ลบไม่สำเร็จ');
        } catch (_) {
          throw Exception('ลบไม่สำเร็จ (${response.statusCode})');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Connection error: $e');
    }
  }

  static Future<String> saveName({
    required String name,
    required String day,
    required int totalScore,
    required int satSum,
    required int shaSum,
  }) async {
    final url = Uri.parse('$baseUrl/api/saved-names');
    try {
      final token = await AuthService.getToken();
      
      if (token == null) {
        throw Exception('กรุณาเข้าสู่ระบบก่อนบันทึกชื่อ');
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'birth_day': day,
          'total_score': totalScore,
          'sat_sum': satSum,
          'sha_sum': shaSum,
        }),
      );

      if (response.statusCode == 200) {
        return 'บันทึกชื่อเรียบร้อยแล้ว';
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        await AuthService.logout();
        throw Exception('กรุณาเข้าสู่ระบบก่อนบันทึกชื่อ');
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['error'] ?? 'บันทึกไม่สำเร็จ');
        } catch (_) {
          throw Exception('บันทึกไม่สำเร็จ (${response.statusCode})');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow; // Preserve original exception message
      }
      throw Exception(e.toString());
    }
  }

  static Future<List<SampleName>> getSampleNames() async {
    final url = Uri.parse('$baseUrl/api/sample-names');
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => SampleName.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load sample names');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}
