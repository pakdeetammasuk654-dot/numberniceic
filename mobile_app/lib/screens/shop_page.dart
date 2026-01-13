import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../models/product_model.dart';
import '../widgets/payment_modal.dart';
import '../widgets/shared_footer.dart';
import '../widgets/adaptive_footer_scroll_view.dart';
import '../widgets/lucky_number_card.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/local_notification_storage.dart';
import '../utils/custom_toast.dart';
import 'login_page.dart';
import 'dashboard_page.dart'; // To refresh dashboard or navigate? Actually we'll just show dialog.
import 'main_tab_page.dart';
import 'number_analysis_page.dart';
import 'shipping_address_page.dart';
import 'notification_list_page.dart';
import '../widgets/contact_purchase_modal.dart';
import '../widgets/buddhist_day_badge.dart';

import '../widgets/category_nested_donut.dart';
import '../viewmodels/analyzer_view_model.dart';
import '../widgets/auto_scrolling_avatar_list.dart';
import '../models/sample_name.dart';

class ShopPage extends StatefulWidget {
  final AnalyzerViewModel? viewModel;
  const ShopPage({super.key, this.viewModel});
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late Future<List<ProductModel>> _productsFuture;
  late Future<List<SampleName>> _sampleNamesFuture;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  bool _showScrollToTop = false;
  // Notification State
  bool _hasUnreadNotification = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _productsFuture = ApiService.getProducts();
    _sampleNamesFuture = ApiService.getSampleNames();
    
    // Listen to ViewModel changes
    widget.viewModel?.addListener(_onViewModelUpdate);
    
    // Initialize name controller with current name from viewModel
    if (widget.viewModel != null) {
      _nameController.text = widget.viewModel!.currentName;
    }

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

    // Check for pending purchase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndResumePendingPurchase();
      _checkNotification();
    });
  }

  void _onViewModelUpdate() {
    if (mounted) setState(() {});
    if (widget.viewModel != null && _nameController.text != widget.viewModel!.currentName) {
      _nameController.text = widget.viewModel!.currentName;
      if (_nameController.selection.baseOffset == -1) {
        _nameController.selection = TextSelection.fromPosition(TextPosition(offset: _nameController.text.length));
      }
    }
  }

  @override
  void dispose() {
    widget.viewModel?.removeListener(_onViewModelUpdate);
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkAndResumePendingPurchase() async {
    final pending = await AuthService.getPendingPurchase();
    if (pending != null && await AuthService.isLoggedIn()) {
      // Clear right away to prevent infinite loops
      await AuthService.setPendingPurchase(null);
      
      if (!mounted) return;
      
      final product = ProductModel.fromJson(pending);
      _confirmPurchase(product);
    }
  }

  Future<void> _checkNotification() async {
    // Only check if logged in
    final token = await AuthService.getToken();
    final isLoggedIn = token != null;
    
    if (isLoggedIn) {
        try {
            final count = await ApiService.getUnreadNotificationCount();
            if (mounted) {
                setState(() {
                    _unreadCount = count;
                    _hasUnreadNotification = count > 0;
                });
            }
        } catch (_) {}
    }
  }

  void _handleNotificationTap() {
    AuthService.isLoggedIn().then((isLoggedIn) {
       if (isLoggedIn) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationListPage()))
              .then((_) {
                 _checkNotification();
                 // Reset unread count logic if needed here or let _checkNotification handles it
              });
       } else {
          CustomToast.show(context, 'กรุณาเข้าสู่ระบบเพื่อดูการแจ้งเตือน'); 
       }
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = ApiService.getProducts();
      _checkNotification();
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
                   Expanded(child: Text('แถมฟรี! สิทธิ์ VIP 1 ปี', style: GoogleFonts.kanit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[800]))),
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
                  // Save pending purchase
                  await AuthService.setPendingPurchase(product.toJson());
                  
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
        onPaymentSuccess: (String vipCode) async {
          Navigator.pop(context); // Close payment modal
          
          // Refresh User Profile to update VIP status immediately
          await AuthService.refreshUserProfile();

          if (context.mounted) {
            _showSuccessDialog(productName, vipCode);
          }
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDE7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text('เปิดใช้งาน VIP สำเร็จ!', style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ระบบได้รับการชำระเงินและ\nปรับสถานะ VIP ให้คุณโดยอัตโนมัติแล้ว',
              style: GoogleFonts.kanit(fontSize: 15, fontWeight: FontWeight.bold, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'คุณสามารถเข้าใช้งานฟีเจอร์ VIP ทั้งหมดได้ทันที\nโดยไม่ต้องกรอกรหัสใดๆ เพิ่มเติม',
              style: GoogleFonts.kanit(fontSize: 13, color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text('รหัสอ้างอิง: $code', style: GoogleFonts.kanit(fontSize: 10, color: Colors.grey[400])),
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
                    MaterialPageRoute(builder: (context) => const MainTabPage(initialIndex: 3)),
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
    // Extract Solar System Data if available
    final solar = widget.viewModel?.analysisResult?.solarSystem;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF1A1A2E),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
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
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                controller: _scrollController,
                slivers: [
                  if (context.findAncestorWidgetOfExactType<NestedScrollView>() != null)
                    SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),

                  // Donut Chart Section with Loading State
                  // Empty State for Donut
                  if (widget.viewModel?.isSolarLoading == false && solar == null)
                     SliverToBoxAdapter(
                       child: Container(
                          height: 300,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                               const Icon(Icons.trending_up_rounded, size: 64, color: Colors.white24),
                               const SizedBox(height: 24),
                               Text('วิเคราะห์ชื่อตามตำรา', style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)),
                               const SizedBox(height: 8),
                               Text('เลขศาสตร์ พลังเงา', textAlign: TextAlign.center, style: GoogleFonts.kanit(fontSize: 16, color: Colors.white38)),
                            ],
                          ),
                       ),
                     )
                  else if (widget.viewModel?.isSolarLoading == true && solar == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40, bottom: 24),
                        child: _buildSolarSystemSkeleton(),
                      ),
                    )
                  else if (solar != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 24),
                        child: CategoryNestedDonut(
                          categoryBreakdown: solar.categoryBreakdown, 
                          totalPairs: solar.totalPairs, 
                          grandTotalScore: solar.grandTotalScore.toInt(), 
                          totalPositiveScore: solar.totalPositiveScore, 
                          totalNegativeScore: solar.totalNegativeScore,
                          analyzedName: solar.cleanedName,
                          onAddPhoneNumber: (_) => _scrollToTop(),
                        ),
                      ),
                    ),

                  // Product List
                  FutureBuilder<List<ProductModel>>(
                    future: _productsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())));
                      } else if (snapshot.hasError) {
                        return SliverToBoxAdapter(child: Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}', style: GoogleFonts.kanit())));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                         return const SliverToBoxAdapter(child: Center(child: Text('ไม่พบสินค้า', style: TextStyle(fontFamily: 'Kanit'))));
                      }

                      final products = snapshot.data!;
                      
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = products[index];
                            final cleanName = product.name.replaceAll(RegExp(r'[^0-9]'), '');
                            final isPhone = cleanName.length == 10;

                            if (isPhone) {
                              int sum = 0;
                              try {
                                sum = product.name.split('').fold(0, (p, c) => p + int.parse(c));
                              } catch (_) {}
                              
                              final keywords = product.description.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                              if(keywords.isEmpty) keywords.add(product.description);

                              return LuckyNumberCard(
                                phoneNumber: product.name,
                                sum: sum,
                                isVip: true,
                                keywords: keywords,
                                buyButtonLabel: 'ซื้อเบอร์นี้',
                                onBuy: () => _confirmPurchase(product),
                                onAnalyze: () {
                                    CustomToast.show(context, 'Analysis for ${product.name}');
                                },
                                onClose: () {},
                              );
                            }

                            return Container(
                              height: 480,
                              decoration: const BoxDecoration(color: Colors.white),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [ _parseColor(product.imageColor1), _parseColor(product.imageColor2)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                  if (product.imagePath != null && product.imagePath!.isNotEmpty)
                                    Image.network(
                                        product.imagePath!.startsWith('http') 
                                            ? product.imagePath! 
                                            : '${ApiService.baseUrl}${product.imagePath!.startsWith('/') ? '' : '/'}${product.imagePath}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                    ),
                                  if (product.imagePath == null || product.imagePath!.isEmpty)
                                    Center(
                                      child: Icon(
                                         product.iconType == 'coin' ? Icons.monetization_on : Icons.volunteer_activism, 
                                         size: 140, 
                                         color: Colors.white.withOpacity(0.25)
                                       ),
                                    ),
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
                                  Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
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
                                                'แถมฟรี! สิทธิ์ VIP 1 ปี', 
                                                style: GoogleFonts.kanit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
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
                                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
                          childCount: products.length,
                        ),
                      );
                    },
                  ),
                  
                  // Footer
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SharedFooter(),
                    ),
                  ),
                ],
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

  Widget _buildSolarSystemSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 80),
          // Loading message
          Text(
            'กำลังวิเคราะห์จาก +3 แสนรายชื่อ...',
            style: GoogleFonts.kanit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // Loading indicator
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
          const SizedBox(height: 60),
          Container(width: 120, height: 40, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 20),
          Container(height: 400, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(24))),
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


