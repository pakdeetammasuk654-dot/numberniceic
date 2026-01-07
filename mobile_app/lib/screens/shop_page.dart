import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../models/product_model.dart';
import '../widgets/payment_modal.dart';
import '../widgets/shared_footer.dart';
import '../widgets/lucky_number_card.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/custom_toast.dart';
import 'login_page.dart';
import 'dashboard_page.dart'; // To refresh dashboard or navigate? Actually we'll just show dialog.
import 'main_tab_page.dart';
import '../widgets/contact_purchase_modal.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late Future<List<ProductModel>> _productsFuture;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _productsFuture = ApiService.getProducts();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        bool show = _scrollController.offset > 100;
        if (show != _showScrollToTop) {
          setState(() {
            _showScrollToTop = show;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = ApiService.getProducts();
    });
  }



  void _confirmPurchase(ProductModel product) {
    debugPrint('🖱️ Clicked Buy: ${product.name}');
    // Check if product is a phone number (Lucky Number)
    final cleanName = product.name.replaceAll(RegExp(r'[^0-9]'), '');
    final isPhone = cleanName.length >= 9 && cleanName.length <= 10; // Relaxed check
    debugPrint('📞 isPhone: $isPhone (Clean: $cleanName)');

    if (isPhone) {
      debugPrint('🚀 Showing Contact Modal');
      showDialog(
        context: context,
        builder: (context) => ContactPurchaseModal(phoneNumber: product.name),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการสั่งซื้อ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คุณต้องการสั่งซื้อสินค้าชิ้นนี้ใช่หรือไม่?', style: GoogleFonts.kanit()),
            const SizedBox(height: 12),
            Text(product.name, style: GoogleFonts.kanit(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${product.price} บาท', style: GoogleFonts.kanit(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                   const Icon(Icons.stars, color: Colors.amber, size: 24),
                   const SizedBox(width: 8),
                   Expanded(child: Text('แถมฟรี! รหัส VIP 1 ปี', style: GoogleFonts.kanit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[800]))),
                ],
              ),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Check if logged in
              bool loggedIn = await AuthService.isLoggedIn();
              if (!loggedIn) {
                if (context.mounted) {
                  CustomToast.show(context, 'กรุณาเข้าสู่ระบบก่อนสั่งซื้อ', isSuccess: false);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                }
                return;
              }
              _processPurchase(product);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2d3748), foregroundColor: Colors.white),
            child: Text('ยืนยันคำสั่งซื้อ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _processPurchase(ProductModel product) async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await ApiService.buyProduct(product.name);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        
        final refNo = result['ref_no'] as String;
        final amount = result['amount'] as num;
        final qrCodeUrl = result['qr_code_url'] as String;
        
        _showPaymentModal(refNo, amount.toDouble(), qrCodeUrl, product.name);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        CustomToast.show(context, e.toString().replaceAll('Exception: ', ''), isSuccess: false);
      }
    }
  }

  void _showPaymentModal(String refNo, double amount, String qrCodeUrl, String productName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentModal(
        refNo: refNo,
        amount: amount,
        qrCodeUrl: qrCodeUrl,
        productName: productName,
        onPaymentSuccess: (String vipCode) {
          Navigator.pop(context); // Close payment modal
          _showSuccessDialog(productName, vipCode);
        },
      ),
    );
  }

  void _showSuccessDialog(String productName, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text('สั่งซื้อสำเร็จ!', style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('ขอบคุณที่สั่งซื้อ $productName', style: GoogleFonts.kanit(color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Text('รหัส VIP ของคุณ', style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(code, style: GoogleFonts.kanit(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.blue),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          CustomToast.show(context, 'คัดลอกรหัสแล้ว');
                        },
                      )
                    ],
                  ),
                ],
              ),
            ),
             const SizedBox(height: 16),
             Text('*ระบบได้บันทึกรหัสนี้ไว้ในแดชบอร์ดของคุณเรียบร้อยแล้ว', style: GoogleFonts.kanit(fontSize: 10, color: Colors.grey[500]), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                // Optionally navigate to Dashboard or just stay here
                // Navigating to dashboard (Tab 2) to see the code
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const MainTabPage(initialIndex: 2)),
                    (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: const Color(0xFF28a745),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('ไปที่แดชบอร์ดเพื่อใช้สิทธิ์', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('ซื้อสินค้าร้านมาดี', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF333333),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                if (notification.metrics.pixels > 100 && !_showScrollToTop) {
                  setState(() => _showScrollToTop = true);
                } else if (notification.metrics.pixels <= 100 && _showScrollToTop) {
                  setState(() => _showScrollToTop = false);
                }
              }
              return true;
            },
            child: RefreshIndicator(
              onRefresh: _refreshProducts,
              child: FutureBuilder<List<ProductModel>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}', style: GoogleFonts.kanit()));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                     return const Center(child: Text('ไม่พบสินค้า', style: TextStyle(fontFamily: 'Kanit')));
                  }

                  final products = snapshot.data!;
                  
                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      // Check if product name is a phone number (Allowing 10 digits with optional formatting)
                      final cleanName = product.name.replaceAll(RegExp(r'[^0-9]'), '');
                      final isPhone = cleanName.length == 10;

                      if (isPhone) {
                        // Lucky Number Card Logic
                        int sum = 0;
                        try {
                          sum = product.name.split('').fold(0, (p, c) => p + int.parse(c));
                        } catch (_) {}
                        
                        final keywords = product.description.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        if(keywords.isEmpty) keywords.add(product.description);

                        return LuckyNumberCard(
                          phoneNumber: product.name,
                          sum: sum,
                          isVip: true, // Shop items are generally premium
                          keywords: keywords,
                          buyButtonLabel: 'ซื้อเบอร์นี้', // Changed for visual confirmation
                          onBuy: () => _confirmPurchase(product),
                          onAnalyze: () {
                              CustomToast.show(context, 'Analysis for ${product.name}');
                          },
                          onClose: () {},
                        );
                      }

                      return Container(
                        height: 480, // Taller magazine-style card for full impact
                        decoration: BoxDecoration(
                          color: Colors.white,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                                  // 1. Foundation Color/Gradient
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [ _parseColor(product.imageColor1), _parseColor(product.imageColor2)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                  
                                  // 2. High-Impact Image
                                  if (product.imagePath != null && product.imagePath!.isNotEmpty)
                                    Image.network(
                                        product.imagePath!.startsWith('http') 
                                            ? product.imagePath! 
                                            : '${ApiService.baseUrl}${product.imagePath!.startsWith('/') ? '' : '/'}${product.imagePath}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                    ),
                                  
                                  // 3. Iconic Visual (if no image)
                                  if (product.imagePath == null || product.imagePath!.isEmpty)
                                    Center(
                                      child: Icon(
                                         product.iconType == 'coin' ? Icons.monetization_on : Icons.volunteer_activism, 
                                         size: 140, 
                                         color: Colors.white.withOpacity(0.25)
                                       ),
                                    ),

                                  // 4. Magazine Gradient Overlay
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.05),
                                          Colors.black.withOpacity(0.4),
                                          Colors.black.withOpacity(0.85),
                                        ],
                                        stops: const [0.0, 0.4, 0.6, 1.0],
                                      ),
                                    ),
                                  ),

                                  // 5. Typography and Action Layer
                                  Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 14),
                                              const SizedBox(width: 6),
                                              Text(
                                                'แถมฟรี! รหัส VIP 1 ปี', 
                                                style: GoogleFonts.kanit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Magazine Headline
                                        Text(
                                          product.name, 
                                          style: GoogleFonts.kanit(
                                            fontSize: 34, 
                                            fontWeight: FontWeight.bold, 
                                            color: Colors.white,
                                            height: 1.05,
                                            shadows: [
                                              Shadow(color: Colors.black.withOpacity(0.6), blurRadius: 15, offset: const Offset(0, 4))
                                            ]
                                          )
                                        ),
                                        const SizedBox(height: 10),
                                        // Description
                                        Text(
                                          product.description, 
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.kanit(
                                            color: Colors.white.withOpacity(0.85), 
                                            fontSize: 15, 
                                            height: 1.5,
                                            fontWeight: FontWeight.w300
                                          )
                                        ),
                                        const SizedBox(height: 32),
                                        // Action Row
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('PRICE', style: GoogleFonts.kanit(fontSize: 12, color: Colors.white54, letterSpacing: 2)),
                                                Text('${product.price} ฿', style: GoogleFonts.kanit(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                                              ],
                                            ),
                                            ElevatedButton(
                                              onPressed: () => _confirmPurchase(product),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor: const Color(0xFF1a202c),
                                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                                elevation: 8,
                                              ),
                                              child: Text('สั่งซื้อตอนนี้', style: GoogleFonts.kanit(fontSize: 17, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          if (_showScrollToTop)
            Positioned(
              right: 20,
              bottom: 30, 
              child: FloatingActionButton(
                heroTag: 'shop_scroll_top_final',
                onPressed: _scrollToTop,
                backgroundColor: const Color(0xFF2d3748),
                mini: true,
                elevation: 10,
                child: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 30),
              ),
            ),
        ],
      ),
    );
  }

  Color _parseColor(String? colorStr) {
      if (colorStr == null || colorStr.isEmpty) return Colors.grey;
      try {
        // Assume hex format #RRGGBB
        String hex = colorStr.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF' + hex;
        return Color(int.parse(hex, radix: 16));
      } catch (e) {
        return Colors.grey; // Fallback
      }
  }
}


