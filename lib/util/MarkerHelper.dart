import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerHelper {
  static Future<BitmapDescriptor> createCustomMarkerBitmapNoText(
      ui.Image image, int h, int w, {double pixelRatio = 1.0}) async {
    final int pw = (w * pixelRatio).round();
    final int ph = (h * pixelRatio).round();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder);
    final Rect oval = Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble());

    paintImage(canvas: c, image: image, rect: oval, fit: BoxFit.fitWidth);

    final ui.Picture p = recorder.endRecording();
    final ByteData? pngBytes =
        await (await p.toImage(pw, ph)).toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(Uint8List.view(pngBytes.buffer), imagePixelRatio: pixelRatio);
  }

  /// Creates a small filled circle marker for route stop dots.
  static Future<BitmapDescriptor> createDotMarker({double size = 10, double pixelRatio = 1.0}) async {
    final int ps = (size * pixelRatio).round();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder);
    final center = Offset(ps / 2, ps / 2);
    final radius = ps / 2;
    c.drawCircle(center, radius, Paint()..color = const Color(0xFF9E9E9E));
    c.drawCircle(center, radius - pixelRatio, Paint()..color = const Color(0xFFFFFFFF));
    final ui.Picture p = recorder.endRecording();
    final ByteData? pngBytes =
        await (await p.toImage(ps, ps)).toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(Uint8List.view(pngBytes.buffer), imagePixelRatio: pixelRatio);
  }

  /// Creates a marker for each bus with the route number drawn on top.
  static Future<BitmapDescriptor> createCustomMarkerBitmap(
      String title, int index, ui.Image image,
      {int width = 36, int height = 36, double pixelRatio = 1.0}) async {
    final int pw = (width * pixelRatio).round();
    final int ph = (height * pixelRatio).round();

    final double fontSize = (title.length >= 3 ? height * 0.27 : height * 0.35) * pixelRatio;

    final TextSpan span = TextSpan(
      style: TextStyle(
        color: Colors.black87,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
      text: title,
    );

    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder);
    final Rect oval = Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble());

    paintImage(canvas: c, image: image, rect: oval, fit: BoxFit.fitWidth);

    tp.layout();
    tp.paint(c, Offset(
      (pw - tp.width) / 2,
      (ph - tp.height) / 2 - ph * 0.08,
    ));

    final ui.Picture p = recorder.endRecording();
    final ByteData? pngBytes =
        await (await p.toImage(pw, ph)).toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(Uint8List.view(pngBytes.buffer), imagePixelRatio: pixelRatio);
  }
}
