import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../models/product_model.dart';
import '../widgets/payment_modal.dart';
import '../widgets/shared_footer.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/custom_toast.dart';
import 'dashboard_page.dart'; // To refresh dashboard or navigate? Actually we'll just show dialog.
import 'main_tab_page.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late Future<List<ProductModel>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = ApiService.getProducts();
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = ApiService.getProducts();
    });
  }

  void _confirmPurchase(ProductModel product) {
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
            onPressed: () {
              Navigator.pop(context);
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
      body: RefreshIndicator(
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
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Header (Gradient Mock)
                        // Image Header
                        SizedBox(
                          height: 180,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                                // Background (Always show gradient as base/placeholder)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    gradient: LinearGradient(
                                      colors: [ _parseColor(product.imageColor1), _parseColor(product.imageColor2)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                                // Image (if exists)
                                if (product.imagePath != null && product.imagePath!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    child: Image.network(
                                        product.imagePath!.startsWith('http') 
                                            ? product.imagePath! 
                                            : '${ApiService.baseUrl}${product.imagePath!.startsWith('/') ? '' : '/'}${product.imagePath}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                            return const SizedBox(); // Fallback to seeing the gradient behind
                                        },
                                    ),
                                  ),
                                // Icon (only if no image)
                                if (product.imagePath == null || product.imagePath!.isEmpty)
                                  Center(
                                    child: Icon(
                                       product.iconType == 'coin' ? Icons.monetization_on : Icons.volunteer_activism, 
                                       size: 80, 
                                       color: Colors.white.withOpacity(0.9)
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(product.name, style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                                    child: Text('แถม VIPฟรี', style: GoogleFonts.kanit(fontSize: 10, color: Colors.green[800], fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(product.description, style: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 13, height: 1.5)),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Text('${product.price} ฿', style: GoogleFonts.kanit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF2d3748))),
                                  const Spacer(),
                                  ElevatedButton(
                                    onPressed: () => _confirmPurchase(product),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2d3748),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text('สั่งซื้อสินค้า', style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
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


