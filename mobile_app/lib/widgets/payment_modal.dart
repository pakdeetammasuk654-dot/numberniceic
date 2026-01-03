import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/custom_toast.dart';

class PaymentModal extends StatefulWidget {
  final String refNo;
  final double amount;
  final String qrCodeUrl;
  final String productName;
  final Function(String vipCode) onPaymentSuccess;

  const PaymentModal({
    super.key,
    required this.refNo,
    required this.amount,
    required this.qrCodeUrl,
    required this.productName,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  late int _remainingSeconds;
  Timer? _timer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 600; // 10 minutes
    _startTimer();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context);
          CustomToast.show(context, 'หมดเวลาทำรายการ กรุณาทำรายการใหม่', isSuccess: false);
        }
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final result = await ApiService.checkShopPaymentStatus(widget.refNo);
        if (result['paid'] == true) {
          timer.cancel();
          _timer?.cancel();
          if (mounted) {
            final vipCode = result['vip_code'] as String? ?? 'VIP-ACTIVATED';
            widget.onPaymentSuccess(vipCode);
          }
        }
      } catch (e) {
        // Continue polling on error
      }
    });
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF2d3748),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Text(
                    'ชำระเงิน',
                    style: GoogleFonts.kanit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ref: ${widget.refNo}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'สแกน QR Code เพื่อชำระเงิน',
                    style: GoogleFonts.kanit(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  // QR Code
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildQRImage(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Amount
                  Text(
                    '${widget.amount.toStringAsFixed(0)} ฿',
                    style: GoogleFonts.kanit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2d3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'ชำระภายใน $_formattedTime นาที',
                          style: GoogleFonts.kanit(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Polling indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.blue[300]),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'กำลังตรวจสอบยอดเงิน...',
                        style: GoogleFonts.kanit(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'สามารถดูรายการได้ที่ประวัติสั่งซื้อ',
                    style: GoogleFonts.kanit(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'ปิดหน้าต่าง',
                        style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRImage() {
    if (widget.qrCodeUrl.startsWith('data:image')) {
      // Base64 encoded image
      try {
        final base64String = widget.qrCodeUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (e) {
        return const Center(child: Icon(Icons.error, color: Colors.red));
      }
    } else {
      // URL
      return Image.network(widget.qrCodeUrl, fit: BoxFit.contain);
    }
  }
}
