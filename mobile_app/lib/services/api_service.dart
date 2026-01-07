import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/sample_name.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/shipping_address_model.dart';
import 'auth_service.dart';
import '../models/user_notification.dart';

class ApiService {
  static final ValueNotifier<int> dashboardRefreshSignal = ValueNotifier<int>(0);

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    
    // Domain จริง (Production) - Punycode Encoded for 'www.ชื่อดี.com'
    const String productionDomain = 'www.xn--b3cu8e7ah6h.com';
    
    // IP สำหรับ Local Development
    const String localIp = '192.168.1.38'; // แก้เป็น IP Mac ของคุณ
    
    // เลือกโหมด: หากเป็น kReleaseMode (ตอน Build App จริง) ให้ใช้ Domain
    // หากเป็น Debug Mode ให้ใช้ IP หรือ localhost
    // เลือกโหมด: หากเป็น kReleaseMode (ตอน Build App จริง) ให้ใช้ Domain
    // หากเป็น Debug Mode ให้ใช้ IP หรือ localhost
    const bool useProduction = false; // Set to true for production builds

    if (useProduction || kReleaseMode) {
      return 'https://$productionDomain';
    }

    if (Platform.isAndroid) {
      // 10.0.2.2 คือ IP ที่ Android Emulator ใช้เรียกเครื่อง Host (localhost)
      // return 'http://10.0.2.2:3000'; // For Emulator
      return 'http://$localIp:3000'; // For Real Device via LAN
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
        final data = json.decode(response.body);
        if (data == null || data is! List) return [];
        return data.map((item) => ShippingAddress.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load addresses');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
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

  static Future<Map<String, dynamic>> analyzeName(
    String name,
    String day, {
    bool auspicious = false,
    bool disableKlakini = false,
    bool disableKlakiniTop4 = false,
    String? section,
  }) async {
    final queryParams = {
      'name': name,
      'day': day,
      'auspicious': auspicious.toString(),
      'disable_klakini': disableKlakini.toString(),
      'disable_klakini_top4': disableKlakiniTop4.toString(),
    };
    if (section != null) queryParams['section'] = section;
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
    final url = Uri.parse('$baseUrl/api/analyze-linguistically').replace(queryParameters: {'name': name});
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to analyze name linguistically: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  static Future<Map<String, dynamic>> analyzeRawNumber(String number) async {
    final url = Uri.parse('$baseUrl/api/number-analysis').replace(queryParameters: {'number': number});
    debugPrint('🚀 API REQUEST: GET $url');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to analyze number: ${response.statusCode}');
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

      final data = json.decode(response.body);

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
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => ProductModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
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

      final data = json.decode(response.body);

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
        return json.decode(response.body);
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
        final data = json.decode(response.body);
        final List<dynamic> ordersJson = data['orders'] ?? [];
        return ordersJson.map((json) => OrderModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
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
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
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
        final data = json.decode(response.body);
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
  static Future<Map<String, dynamic>?> getWelcomeMessage() async {
    final url = Uri.parse('$baseUrl/api/system/welcome-message');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- Notifications ---

  static Future<List<UserNotification>> getUserNotifications() async {
    final url = Uri.parse('$baseUrl/api/notifications');
    final token = await AuthService.getToken();
    if (token == null) return [];

    try {
      if (kDebugMode) print('🚀 API REQUEST: GET $url (Authenticated)');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => UserNotification.fromJson(e)).toList();
      }
      if (kDebugMode) print('❌ API RESPONSE: ${response.statusCode} for notifications');
      return [];
    } catch (e) {
      if (kDebugMode) print('❌ API ERROR: Fetch notifications: $e');
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
          final data = json.decode(response.body);
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
}
