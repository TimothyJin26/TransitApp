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
  /// If [ageLabel] is provided (e.g. "30" or "2m"), a small pill matching
  /// TransitLiveTimer style is drawn in the top-right corner of the icon.
  static Future<BitmapDescriptor> createCustomMarkerBitmap(
      String title, int index, ui.Image image,
      {int width = 36, int height = 36, double pixelRatio = 1.0,
      String? ageLabel, bool isDark = false}) async {
    final int pw = (width * pixelRatio).round();
    final int ph = (height * pixelRatio).round();

    final double pillLogH = 14 * pixelRatio;
    final double pillRadius = 7 * pixelRatio;

    // Extra canvas height at top to accommodate the pill without clipping.
    final double pillExtraH = ageLabel != null ? (pillLogH + 2 * pixelRatio) : 0;
    final int totalH = ph + pillExtraH.round();

    final double fontSize = (title.length >= 3 ? height * 0.27 : height * 0.35) * pixelRatio;

    final TextPainter tp = TextPainter(
      text: TextSpan(
        style: TextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        text: title,
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder);

    // Bus icon shifted down to leave room for pill above.
    paintImage(
      canvas: c,
      image: image,
      rect: Rect.fromLTWH(0, pillExtraH, pw.toDouble(), ph.toDouble()),
      fit: BoxFit.fitWidth,
    );

    tp.layout();
    tp.paint(c, Offset(
      (pw - tp.width) / 2,
      pillExtraH + (ph - tp.height) / 2 - ph * 0.08,
    ));

    if (ageLabel != null) {
      final bgColor = isDark
          ? const Color.fromRGBO(50, 52, 58, 1)
          : const Color.fromRGBO(255, 255, 255, 0.95);
      final contentColor = isDark
          ? const Color.fromRGBO(142, 142, 147, 1)
          : Colors.grey;

      final iconFontSize = 8.0 * pixelRatio;
      final iconTp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(Icons.rss_feed.codePoint),
          style: TextStyle(
            color: contentColor,
            fontSize: iconFontSize,
            fontFamily: 'MaterialIcons',
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelFontSize = 7.5 * pixelRatio;
      final labelTp = TextPainter(
        text: TextSpan(
          text: ageLabel,
          style: TextStyle(
            color: contentColor,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w400,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final padX = 2.5 * pixelRatio;
      final gapX = 2.0 * pixelRatio;
      final totalContentW = iconTp.width + gapX + labelTp.width;
      final dynamicPillW = totalContentW + padX * 2;
      final pillH = pillLogH;

      final pillLeft = pw - dynamicPillW;
      const pillTop = 0.0;

      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pillLeft, pillTop, dynamicPillW, pillH),
          Radius.circular(pillRadius),
        ),
        Paint()..color = bgColor,
      );

      double x = pillLeft + padX;
      final centerY = pillTop + pillH / 2;

      iconTp.paint(c, Offset(x, centerY - iconTp.height / 2));
      x += iconTp.width + gapX;
      labelTp.paint(c, Offset(x, centerY - labelTp.height / 2));
    }

    final ui.Picture p = recorder.endRecording();
    final ByteData? pngBytes =
        await (await p.toImage(pw, totalH)).toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(Uint8List.view(pngBytes.buffer), imagePixelRatio: pixelRatio);
  }
}
