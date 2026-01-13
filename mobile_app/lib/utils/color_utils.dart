import 'package:flutter/material.dart';

class ColorUtils {
  static Color? tryParseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return null;
    try {
      String hex = hexColor.toUpperCase().replaceAll('#', '').replaceAll('0X', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
    } catch (e) {}
    return null;
  }

  static Color parseColor(String? hexColor) {
    return tryParseColor(hexColor) ?? Colors.grey;
  }
}
