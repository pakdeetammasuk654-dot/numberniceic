import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../widgets/payment_modal.dart';
import '../widgets/shared_footer.dart';
import '../utils/custom_toast.dart';
import 'main_tab_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    setState(() {
      _ordersFuture = ApiService.getMyOrders();
    });
  }

  Future<void> _resumePayment(OrderModel order) async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final info = await ApiService.getPaymentInfo(order.refNo);
      if (mounted) {
        Navigator.pop(context); // Close loading
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PaymentModal(
            refNo: info['ref_no'],
            amount: (info['amount'] as num).toDouble(),
            qrCodeUrl: info['qr_code_url'],
            productName: info['product_name'] ?? 'สินค้า',
            onPaymentSuccess: (String vipCode) {
              Navigator.pop(context); // Close modal
              _loadOrders(); // Refresh list
              _showSuccessDialog(order.productName);
            },
          ),
        );
        // After dialog is closed (even if cancelled), refresh orders to get updated RefNo from DB
        if (mounted) _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        CustomToast.show(context, e.toString().replaceAll('Exception: ', ''), isSuccess: false);
      }
    }
  }

  void _showSuccessDialog(String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('ชำระเงินสำเร็จ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: Text('ขอบคุณที่สั่งซื้อ $productName รายการของคุณได้รับการยืนยันแล้ว', style: GoogleFonts.kanit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ตกลง', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
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
        title: Text('ประวัติการสั่งซื้อ', 
          style: GoogleFonts.kanit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<OrderModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}', style: GoogleFonts.kanit()));
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async => _loadOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length + 1,
              itemBuilder: (context, index) {
                if (index == orders.length) return const SharedFooter();
                return _buildOrderCard(orders[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt.add(const Duration(hours: 7)));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProductThumbnail(order.productImage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.productName, style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Ref: ${order.refNo}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                _buildStatusBadge(order.status),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('วันที่สั่งซื้อ', style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey)),
                    Text(dateStr, style: GoogleFonts.kanit(fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('ยอดรวม', style: GoogleFonts.kanit(fontSize: 12, color: Colors.grey)),
                    Text('${order.amount.toStringAsFixed(0)} ฿', 
                      style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2C3E50))),
                  ],
                ),
              ],
            ),
          ),
          if (order.isPending) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _resumePayment(order),
                  icon: const Icon(Icons.payment, size: 18, color: Colors.white),
                  label: Text('ชำระเงินต่อ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2d3748), // Premium dark blue-grey
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductThumbnail(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      final fullUrl = imagePath.startsWith('http')
          ? imagePath
          : '${ApiService.baseUrl}${imagePath.startsWith('/') ? '' : '/'}$imagePath';
      debugPrint('📸 Loading Thumbnail: $fullUrl');
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            fullUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
               debugPrint('❌ Image Load Error: $error');
               return const Icon(Icons.shopping_bag, color: Colors.grey);
            },
          ),
        ),
      );
    }
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.shopping_bag, color: Colors.grey),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'paid':
      case 'verified':
        bgColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        label = 'สำเร็จ';
        break;
      case 'pending':
        bgColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        label = 'รอชำระเงิน';
        break;
      case 'failed':
        bgColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        label = 'ไม่สำเร็จ';
        break;
      default:
        bgColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: GoogleFonts.kanit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text('ไม่พบประวัติการสั่งซื้อ', style: GoogleFonts.kanit(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MainTabPage(initialIndex: 2)),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2d3748),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('ไปที่ร้านค้า', style: GoogleFonts.kanit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
