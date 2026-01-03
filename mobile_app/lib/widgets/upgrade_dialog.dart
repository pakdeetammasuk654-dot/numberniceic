import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import '../services/api_service.dart';
import '../utils/custom_toast.dart';

class UpgradeDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const UpgradeDialog({super.key, required this.onSuccess});

  @override
  State<UpgradeDialog> createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends State<UpgradeDialog> {
  bool _isLoading = true;
  String? _qrBase64;
  String? _refNo;
  double? _amount;
  Timer? _statusTimer;
  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    _fetchUpgradeInfo();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUpgradeInfo() async {
    try {
      final info = await ApiService.getUpgradeInfo();
      if (mounted) {
        setState(() {
          _qrBase64 = info['qrBase64'];
          _refNo = info['refNo'];
          _amount = (info['amount'] as num?)?.toDouble();
          _isLoading = false;
        });
        if (_refNo != null) {
          _startPolling();
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, e.toString().replaceAll('Exception: ', ''), isSuccess: false);
        Navigator.pop(context);
      }
    }
  }

  void _startPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_refNo == null) return;
      final status = await ApiService.checkPaymentStatus(_refNo!);
      if (status == 'paid' && mounted) {
        timer.cancel();
        setState(() {
          _isPaid = true;
        });
        widget.onSuccess();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPaid) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            Text('ชำระเงินสำเร็จ!', style: GoogleFonts.kanit(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('คุณได้รับการอัปเกรดเป็น VIP แล้ว', style: GoogleFonts.kanit()),
          ],
        ),
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('อัปเกรดเป็น VIP', style: GoogleFonts.kanit(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ราคาพิเศษ 1 ปี เพียง ${_amount?.toStringAsFixed(0) ?? "599"} บาท',
                    style: GoogleFonts.kanit(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  if (_qrBase64 != null && _qrBase64!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.memory(
                        base64Decode(_qrBase64!.split(',').last),
                        width: 200,
                        height: 200,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('แสกน QR เพื่อชำระเงินด้วย PromptPay',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.kanit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ] else
                    Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Icon(Icons.qr_code_2, color: Colors.white24, size: 80)),
                    ),
                  const SizedBox(height: 16),
                  Text('Ref No: $_refNo', style: GoogleFonts.kanit(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)),
                      ),
                      const SizedBox(width: 8),
                      Text('รอการชำระเงิน...', style: GoogleFonts.kanit(color: const Color(0xFFFFD700), fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
