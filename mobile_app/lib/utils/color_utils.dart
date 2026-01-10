import 'package:flutter/material.dart';

class ColorUtils {
  static Color parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      String hex = hexColor.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF' + hex;
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
}
