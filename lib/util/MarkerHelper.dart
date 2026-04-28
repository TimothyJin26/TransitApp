import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerHelper {
  static Future<BitmapDescriptor> createCustomMarkerBitmapNoText(
      ui.Image image, int h, int w) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas c = Canvas(recorder);
    final Rect oval = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

    paintImage(canvas: c, image: image, rect: oval, fit: BoxFit.fitWidth);

    final ui.Picture p = recorder.endRecording();
    final ByteData? pngBytes =
        await (await p.toImage(w, h)).toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(Uint8List.view(pngBytes.buffer));
  }

  /// Creates a marker for each bus with the route number drawn on top.
  static Future<BitmapDescriptor> createCustomMarkerBitmap(
      String title, int index, ui.Image image,
      {int width = 36, int height = 36}) async {
    final TextSpan span = TextSpan(
      style: TextStyle(
        color: Colors.black87,
        fontSize: title.length >= 3 ? height * 0.27 : height * 0.35,
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
    final Rect oval =
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

    paintImage(canvas: c, image: image, rect: oval, fit: BoxFit.fitWidth);

    tp.layout();
    tp.paint(c, Offset((width - tp.width) / 2, (height - tp.height) / 2 - height * 0.08));

    final ui.Picture p = recorder.endRecording();
    final ByteData? pngBytes =
        await (await p.toImage(width, height))
            .toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(Uint8List.view(pngBytes.buffer));
  }
}
