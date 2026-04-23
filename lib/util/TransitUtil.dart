import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

Color colorFromHex(String hex) {
  final h = hex.toUpperCase().replaceAll('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}

String patternToDirection(String pattern) {
  if (pattern.startsWith('E')) return 'EASTBOUND';
  if (pattern.startsWith('N')) return 'NORTHBOUND';
  if (pattern.startsWith('W')) return 'WESTBOUND';
  if (pattern.startsWith('S')) return 'SOUTHBOUND';
  if (pattern.toLowerCase() == 'outbound') return 'OUTBOUND';
  if (pattern.toLowerCase() == 'inbound') return 'INBOUND';
  return pattern.toUpperCase();
}

String removeLeadingZeros(String s) {
  while (s.isNotEmpty && s[0] == '0') {
    s = s.substring(1);
  }
  return s;
}

Future<ui.Image> loadUiImage(String asset) async {
  final ByteData data = await rootBundle.load(asset);
  final ui.Codec codec =
      await ui.instantiateImageCodec(data.buffer.asUint8List());
  final ui.FrameInfo frame = await codec.getNextFrame();
  return frame.image;
}
