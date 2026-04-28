import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() async {
  final source = File('images/app-icon.png');
  final bytes = await source.readAsBytes();
  final icon = img.decodePng(bytes)!;

  const canvasSize = 1024;
  const iconSize = 320; // how large the icon appears on screen
  const cornerRadius = 72; // rounded corner radius

  // Resize icon to target size
  final resized = img.copyResize(icon, width: iconSize, height: iconSize,
      interpolation: img.Interpolation.cubic);

  // Apply rounded corners by zeroing pixels outside the rounded rect
  for (int y = 0; y < iconSize; y++) {
    for (int x = 0; x < iconSize; x++) {
      if (!_inRoundedRect(x, y, iconSize, iconSize, cornerRadius)) {
        resized.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
      }
    }
  }

  // Place on transparent canvas centered
  final canvas = img.Image(width: canvasSize, height: canvasSize,
      numChannels: 4);
  final offset = (canvasSize - iconSize) ~/ 2;
  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);

  await File('images/splash-icon.png').writeAsBytes(img.encodePng(canvas));
  print('Saved images/splash-icon.png');
}

bool _inRoundedRect(int x, int y, int w, int h, int r) {
  if (x >= r && x < w - r) return true;
  if (y >= r && y < h - r) return true;
  // Check corners
  final cx = x < r ? r : w - r - 1;
  final cy = y < r ? r : h - r - 1;
  if ((x < r || x >= w - r) && (y < r || y >= h - r)) {
    final dx = x - cx;
    final dy = y - cy;
    return sqrt(dx * dx + dy * dy) <= r;
  }
  return true;
}
