import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../models/sample_name.dart';
import '../models/analysis_result.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/shipping_address_model.dart';
import '../models/user_notification.dart';
import 'auth_service.dart';

class ApiService {
  static final ValueNotifier<int> dashboardRefreshSignal = ValueNotifier<int>(0);

  static dynamic _safeDecode(http.Response response) {
    if (response.body.isEmpty) {
      throw Exception('Server returned an empty response (Status: ${response.statusCode})');
    }
    try {
      return json.decode(response.body);
    } catch (e) {
      print('❌ JSON Parse Error Body: ${response.body}');
      // If it's HTML, it might be an error page
      if (response.body.contains('<!DOCTYPE html>') || response.body.contains('<html')) {
          throw Exception('Server returned HTML instead of JSON. This usually indicates a server error (500) or a route not found (404). Status: ${response.statusCode}');
      }
      throw Exception('Failed to parse JSON: $e');
    }
  }


  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    
    // Domain จริง (Production) - Punycode Encoded for 'www.ชื่อดี.com'
    const String productionDomain = 'www.xn--b3cu8e7ah6h.com';
    
    // IP สำหรับ Local Development
    const String localIp = '192.168.1.38'; // แก้เป็น IP Mac ของคุณ
    
    // เลือกโหมด: หากเป็น kReleaseMode (ตอน Build App จริง) ให้ใช้ Domain
    // หากเป็น Debug Mode ให้ใช้ IP หรือ localhost
    const bool useProduction = true; // Set to true for production builds

    if (useProduction || kReleaseMode) {
      return 'https://$productionDomain';
    }

    if (Platform.isAndroid) {
      // 10.0.2.2 is the IP that Android Emulator uses to reach the host machine (localhost)
      return 'http://10.0.2.2:3000'; 
    }
    
    return 'http://$localIp:3000'; // For iOS Real Device / LAN
  }

  // --- Shipping Address API ---

  static Future<List<ShippingAddress>> getShippingAddresses() async {
    final url = Uri.parse('$baseUrl/api/shipping');
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = _safeDecode(response);
        if (data == null || data is! List) return [];
        return data.map((item) => ShippingAddress.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load addresses');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
    }
  }

  static Future<bool> saveShippingAddress(ShippingAddress address) async {
    final url = Uri.parse('$baseUrl/api/shipping');
    try {
      final token = await AuthService.getToken();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(address.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteShippingAddress(int id) async {
    final url = Uri.parse('$baseUrl/api/shipping/$id');
    try {
      final token = await AuthService.getToken();
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Article>> getArticles() async {
    final url = Uri.parse('$baseUrl/api/articles');
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = _safeDecode(response);
        return data.map((json) => Article.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load articles');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
    }
  }

  static Future<Article> getArticleBySlug(String slug) async {
    final url = Uri.parse('$baseUrl/api/articles/$slug');
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = _safeDecode(response);
        return Article.fromJson(data);
      } else {
        throw Exception('Failed to load article');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
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
        final data = _safeDecode(response);
        // Sync with SharedPreferences so bottom bar and other widgets get latest info
        await AuthService.syncAuthData(data);
        return data;
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        await AuthService.logout();
        throw Exception('Session expired');
      } else if (response.statusCode == 404) {
        // User record missing in DB (likely deleted or DB test reset)
        await AuthService.logout();
        throw Exception('User no longer exists');
      } else {
        throw Exception('Failed to load dashboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
    }
  }

  // Get Upcoming Buddhist Days List
  static Future<List<dynamic>> getBuddhistDays() async {
    final response = await http.get(Uri.parse('$baseUrl/api/buddhist-days'));

    if (response.statusCode == 200) {
      // Returns List<Map<String, dynamic>>
      // Each item: { "id": 1, "date": "2024-01-01T00:00:00Z" }
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load buddhist days');
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
        final data = _safeDecode(response);
        return data['is_buddhist_day'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<AnalysisResult> analyzeName(
    String name,
    String day, {
    bool auspicious = false,
    bool disableKlakini = false,
    bool disableKlakiniTop4 = false,
    String section = 'all',
  }) async {
    final queryParams = {
      'name': name,
      'day': day,
      'auspicious': auspicious.toString(),
      'disable_klakini': disableKlakini.toString(),
      'disable_klakini_top4': disableKlakiniTop4.toString(),
      'section': section,
    };
    
    final url = Uri.parse('$baseUrl/api/analyze').replace(queryParameters: queryParams);
    debugPrint('🚀 API REQUEST: GET $url (Section: $section)');

    try {
      final response = await http.get(
          url,
          headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = _safeDecode(response);
        return AnalysisResult.fromJson(data);
      } else {
        throw Exception('Failed to analyze name: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
    }
  }

  static Future<Map<String, dynamic>> analyzeLinguistically(String name) async {
    final url = Uri.parse('$baseUrl/api/analyze-linguistically').replace(queryParameters: {'name': name});
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return _safeDecode(response);
      } else {
        throw Exception('Failed to analyze name linguistically: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
    }
  }

  static Future<Map<String, dynamic>> analyzeRawNumber(String number) async {
    final url = Uri.parse('$baseUrl/api/number-analysis').replace(queryParameters: {'number': number});
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return _safeDecode(response);
      } else {
        throw Exception('Failed to analyze number: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
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
        return _safeDecode(response);
      } else {
        throw Exception('ไม่สามารถดึงข้อมูลชำระเงินได้');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
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
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = _safeDecode(response);
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
          final error = _safeDecode(response);
          throw Exception(error['error'] ?? 'ลบไม่สำเร็จ');
        } catch (_) {
          throw Exception('ลบไม่สำเร็จ (${response.statusCode})');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Connection error at $url: $e');
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
          final error = _safeDecode(response);
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
        final List<dynamic> data = _safeDecode(response);
        return data.map((json) => SampleName.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load sample names');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
    }
  }

  static Future<String> redeemCode(String code) async {
    final url = Uri.parse('$baseUrl/api/redeem-code');
    try {
      final token = await AuthService.getToken();
      
      // Allow attempt without token if app logic requires, but ideally should be protected
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
      };
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'code': code}),
      );

      final data = _safeDecode(response);

      if (response.statusCode == 200) {
        return data['message'] ?? 'ใช้งานรหัสสำเร็จ';
      } else {
        throw Exception(data['error'] ?? 'ใช้งานรหัสไม่สำเร็จ');
      }
    } catch (e) {
        if (e is Exception) rethrow;
        throw Exception(e.toString());
    }
  }

  static Future<List<ProductModel>> getProducts() async {
    final url = Uri.parse('$baseUrl/api/shop/products');
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = _safeDecode(response);
        return data.map((json) => ProductModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
    }
  }

  static Future<Map<String, dynamic>> buyProduct(String productName) async {
    final url = Uri.parse('$baseUrl/api/shop/order');
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('กรุณาเข้าสู่ระบบก่อนทำการสั่งซื้อ');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'product_name': productName}),
      );

      final data = _safeDecode(response);

      if (response.statusCode == 200) {
        // Returns {success: true, order_id: 123, ref_no: "123456789012", amount: 1, qr_code_url: "data:image/png;base64,..."}
        return data;
      } else {
        throw Exception(data['error'] ?? 'สั่งซื้อไม่สำเร็จ');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  // Check payment status
  static Future<Map<String, dynamic>> checkShopPaymentStatus(String refNo) async {
    final url = Uri.parse('$baseUrl/api/shop/status/$refNo');
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('กรุณาเข้าสู่ระบบ');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return _safeDecode(response);
      } else {
        throw Exception('ไม่สามารถตรวจสอบสถานะได้');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }


  // --- Order & Shop API ---

  static Future<List<OrderModel>> getMyOrders() async {
    final url = Uri.parse('$baseUrl/api/shop/my-orders');
    debugPrint('Calling API: $url');
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (!contentType.contains('application/json') && !response.body.trim().startsWith('{')) {
           throw Exception('Unexpected response (200 OK) but not JSON. Type: $contentType. Body starts with: ${response.body.substring(0, 50)}...');
        }
        final data = _safeDecode(response);
        final List<dynamic> ordersJson = data['orders'] ?? [];
        return ordersJson.map((json) => OrderModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      throw Exception('Connection error at $url: $e');
    }
  }

  static Future<Map<String, dynamic>> getPaymentInfo(String refNo) async {
    final url = Uri.parse('$baseUrl/api/shop/payment-info/$refNo');
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (!response.body.trim().startsWith('{') && !response.body.trim().startsWith('[')) {
           throw Exception('Unexpected response format. Expected JSON but got: ${response.body.substring(0, 50)}...');
        }
        return _safeDecode(response);
      } else {
        final errorData = _safeDecode(response);
        final errorMessage = errorData['error'] ?? 'Failed to load payment info';
        throw Exception(errorMessage);
      }
    } catch (e) {
       if (e.toString().contains('FormatException') || e.toString().contains('Unexpected response')) {
         throw Exception('Server returned invalid data. Please try again.');
       }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
  // --- Lucky Number API ---
  static Future<Map<String, dynamic>?> getLuckyNumber(String category, {int index = 0}) async {
    final url = Uri.parse('$baseUrl/api/lucky-number?category=${Uri.encodeComponent(category)}&index=$index');
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        url,
        headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
        }
      );

      if (response.statusCode == 200) {
        final data = _safeDecode(response);
        if (data is Map<String, dynamic>) {
           return data;
        }
      }
      return null;
    } catch (e) {
      print('Fetch Lucky Number Error: $e');
      return null;
    }
  }
  static Future<Set<int>> getBadNumbers() async {
    final url = Uri.parse('$baseUrl/api/numerology/bad-numbers');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = _safeDecode(response);
        final list = List<int>.from(data['bad_numbers']);
        return list.toSet();
      }
      return {};
    } catch (e) {
      if (kDebugMode) print('Fetch Bad Numbers Error: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>?> getWelcomeMessage() async {
    final url = Uri.parse('$baseUrl/api/system/welcome-message');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return _safeDecode(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- FCM Token ---
  static Future<void> saveDeviceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString(AuthService.keyToken);
    
    if (jwt == null) return; // Not logged in

    final url = Uri.parse('$baseUrl/api/device-token');
    try {
      await http.post(
        url,
        headers: {
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
        },
        body: jsonEncode({
            'token': token,
            'platform': Platform.isAndroid ? 'android' : 'ios',
        }),
      );
      print('✅ Device Token sent to server.');
    } catch (e) {
      print('❌ Error saving device token: $e');
    }
  }

  // --- Notifications ---

  static Future<List<UserNotification>> getUserNotifications() async {
    final url = Uri.parse('$baseUrl/api/notifications');
    final token = await AuthService.getToken();
    
    print('🔔 DEBUG: Fetching Notifications...');
    print('--------------------------------------------------');
    print('🌐 URL: $url');
    print('🔑 Token: ${token != null ? "Present (${token.substring(0, 10)}...)" : "MISSING"}');

    if (token == null) {
      print('❌ DEBUG: Token is missing, returning empty list.');
      return [];
    }

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📦 Body Length: ${response.body.length} bytes');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = _safeDecode(response);
        print('✅ DEBUG: Got ${data.length} notifications from server');
        if (data.isNotEmpty) {
           print('📝 First item: ${data[0]}');
        }
        return data.map((e) => UserNotification.fromJson(e)).toList();
      } else if (response.statusCode == 401) {
        print('⛔ DEBUG: Token expired (401). Logging out...');
        await AuthService.logout();
        throw Exception('Session expired');
      }
      
      print('❌ DEBUG: Server returned error status: ${response.statusCode}');
      print('📄 Body: ${response.body}');
      return [];
    } catch (e) {
      print('❌ DEBUG: Exception fetching notifications: $e');
      return [];
    }
  }

  static Future<int> getUnreadNotificationCount() async {
     final url = Uri.parse('$baseUrl/api/notifications/unread');
     final token = await AuthService.getToken();
     if (token == null) return 0;
     
     try {
       if (kDebugMode) print('🚀 API REQUEST: GET $url (Authenticated)');
       final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $token'},
       );
       if (response.statusCode == 200) {
          final data = _safeDecode(response);
          return data['count'] ?? 0;
       }
       if (kDebugMode) print('❌ API RESPONSE: ${response.statusCode} for unread count');
       return 0;
     } catch (e) {
       if (kDebugMode) print('❌ API ERROR: Unread count: $e');
       return 0;
     }
  }

  static Future<bool> markNotificationAsRead(int id) async {
    final url = Uri.parse('$baseUrl/api/notifications/$id/read');
    final token = await AuthService.getToken();
    if (token == null) return false;

    try {
      if (kDebugMode) print('🚀 API REQUEST: POST $url (Authenticated)');
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('❌ API ERROR: Mark as read: $e');
      return false;
    }
  }

  static Future<bool> createNotification(String title, String message) async {
    final url = Uri.parse('$baseUrl/api/notifications');
    final token = await AuthService.getToken();
    if (token == null) return false;

    try {
      if (kDebugMode) print('🚀 API REQUEST: POST $url (Authenticated)');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'message': message,
        }),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
      if (kDebugMode) print('❌ API RESPONSE: ${response.statusCode} for create notification');
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ API ERROR: Create notification: $e');
      return false;
    }
  }
}
