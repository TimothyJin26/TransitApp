
import 'dart:ui' as ui;

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerHelper {

  ///
  /// Creates a marker for each bus. This is done asynchronously
  /// (in the background) to not block the app.
  ///
  static Future<BitmapDescriptor> createCustomMarkerBitmap(
      String title, int index, ui.Image image) async {
    if (index < 5) {
      print("Starting to create custom marker");
    }
    TextSpan span = new TextSpan(
      style: new TextStyle(
        color: Colors.black87,
        fontSize: 26.0,
        fontWeight: FontWeight.bold,
      ),
      text: title,
    );

    TextPainter tp = new TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    int width = 75;
    int height = 75;

    ui.PictureRecorder recorder = new ui.PictureRecorder();
    Canvas c = new Canvas(recorder);
    Rect oval = Rect.fromLTWH(0, 0, width + 0.0, height + 0.0);

    // Alternatively use your own method to get the image

    paintImage(canvas: c, image: image, rect: oval, fit: BoxFit.fitWidth);

    tp.layout();
    tp.paint(c, new Offset((width - tp.width) / 2, 16));

    /* Do your painting of the custom icon here, including drawing text, shapes, etc. */

    /*like a bad alexa*/
    ui.Picture p = recorder.endRecording();
    ByteData pngBytes = await (await p.toImage(width, height))
        .toByteData(format: ui.ImageByteFormat.png);

    Uint8List data = Uint8List.view(pngBytes.buffer);

    if (index < 5) {
      print("Finished creating custom marker");
    }
    return BitmapDescriptor.fromBytes(data);
  }
}
