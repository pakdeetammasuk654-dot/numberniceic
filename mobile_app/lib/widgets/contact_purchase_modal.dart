import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // Ensure url_launcher is available or use intent
import '../services/api_service.dart';

class ContactPurchaseModal extends StatelessWidget {
  final String phoneNumber;

  const ContactPurchaseModal({
    super.key,
    required this.phoneNumber,
  });

  Future<void> _launchLine() async {
    const lineUrl = 'https://line.me/ti/p/~numberniceic'; // Replace with actual Line Add Friend URL if known, or search ID
    // Or 'line://ti/p/~numberniceic'
    final Uri url = Uri.parse(lineUrl);
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback
       debugPrint('Could not launch line');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFFBEF), // Light cream background like web
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Watermark Background
          Positioned.fill(
             child: ClipRRect(
               borderRadius: BorderRadius.circular(24),
               child: Stack(
                 children: [
                   for(int i=-2; i<8; i++)
                     for(int j=-2; j<8; j++)
                       Positioned(
                         left: i * 80.0,
                         top: j * 80.0,
                         child: Transform.rotate(
                           angle: -0.2,
                           child: Opacity(
                             opacity: 0.05,
                             child: Text(
                               'ชื่อดี.com',
                               style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                             ),
                           ),
                         ),
                       )
                 ],
               ),
             ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Text(
                  'สนใจเบอร์นี้?',
                  style: GoogleFonts.kanit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4A4A4A),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Golden Number
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFD4AF37), // Metallic Gold
                      Color(0xFFFFD700), // Yellow Gold
                      Color(0xFFB8860B), // Dark Goldenrod
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Text(
                    _formatPhoneNumber(phoneNumber),
                    style: GoogleFonts.kanit(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'ติดต่อซื้อเบอร์นี้ได้ที่',
                  style: GoogleFonts.kanit(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Content Box (QR + Line ID)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // QR Code
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // Use NetworkImage with absolute URL
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            'https://www.xn--b3cu8e7ah6h.com/images/line_qr_taya.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Center(
                              child: Icon(Icons.qr_code, size: 48, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Line ID Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEDF2F7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.network(
                              'https://upload.wikimedia.org/wikipedia/commons/4/41/LINE_logo.svg', // Fallback or use local asset if available
                              width: 24, 
                              height: 24,
                              errorBuilder: (c, o, s) => const Icon(Icons.chat_bubble, color: Colors.green, size: 24),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: 
                              Text(
                                'Line ID: numberniceic',
                                style: GoogleFonts.kanit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2D3748),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                              onPressed: () {
                                // Clipboard implementation need import services/flutter services
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Add Friend Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _launchLine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06C755), // Line Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_add, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'เพิ่มเพื่อนใน LINE',
                          style: GoogleFonts.kanit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'ไว้คราวหน้า',
                    style: GoogleFonts.kanit(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Close Icon
          Positioned(
            right: 12,
            top: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPhoneNumber(String number) {
    if (number.length >= 10) {
      return '${number.substring(0, 3)}-${number.substring(3, 6)}-${number.substring(6)}';
    }
    return number;
  }
}
