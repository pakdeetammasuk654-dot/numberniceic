import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomToast {
  static void show(BuildContext context, String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero, // Remove default padding
        backgroundColor: Colors.transparent, // Make background transparent
        elevation: 0, // No shadow from SnackBar
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 30, left: 16, right: 16),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSuccess 
                  ? [const Color(0xFF00b09b), const Color(0xFF96c93d)] // Web Green Gradient
                  : [const Color(0xFFff416c), const Color(0xFFff4b2b)], // Web Red Gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isSuccess ? const Color(0xFF00b09b) : const Color(0xFFff416c)).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.2),
                   shape: BoxShape.circle,
                 ),
                 child: Icon(
                   isSuccess ? Icons.check : Icons.priority_high_rounded,
                   color: Colors.white,
                   size: 24,
                 ),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       message,
                       style: GoogleFonts.kanit(
                         fontSize: 16,
                         fontWeight: FontWeight.w500,
                         color: Colors.white,
                         height: 1.3
                       ),
                     ),
                   ],
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }
}
