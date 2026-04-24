import 'package:flutter/material.dart';

String patternHelper(String s) {
  if (s.startsWith('E')) return 'EASTBOUND';
  if (s.startsWith('N')) return 'NORTHBOUND';
  if (s.startsWith('W')) return 'WESTBOUND';
  if (s.startsWith('S')) return 'SOUTHBOUND';
  if (s.toLowerCase() == 'outbound') return 'OUTBOUND';
  if (s.toLowerCase() == 'inbound') return 'INBOUND';
  return s.toUpperCase();
}

String removeZeroes(String s) {
  while (s.isNotEmpty && s.substring(0, 1) == '0') {
    s = s.substring(1);
  }
  return s;
}

Color getColorFromHex(String hexColor) {
  final String h = hexColor.toUpperCase().replaceAll('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}
