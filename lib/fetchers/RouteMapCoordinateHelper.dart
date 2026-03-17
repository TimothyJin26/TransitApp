import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class RouteMapCoordinateHelper {
  Future<List<List<LatLng>>> getLatLng(String url) async {
    final List<List<LatLng>> finalToRet = [];

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return finalToRet;

    // Decode the KMZ (zip) file
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);

    for (final file in archive) {
      if (!file.isFile) continue;

      final data = file.content as List<int>;
      final String kmlContent = utf8.decode(data);
      final XmlDocument document = XmlDocument.parse(kmlContent);
      final Iterable<XmlElement> coordinateList =
          document.findAllElements('coordinates');

      for (final XmlElement e in coordinateList) {
        final List<LatLng> segment = [];
        final List<String> parts = e.innerText.split('0.0 ');
        for (final String part in parts) {
          final List<String> coords = part.trim().split(',');
          if (coords.length >= 2) {
            final double? lng = double.tryParse(coords[0]);
            final double? lat = double.tryParse(coords[1]);
            if (lat != null && lng != null) {
              segment.add(LatLng(lat, lng));
            }
          }
        }
        if (segment.isNotEmpty) {
          finalToRet.add(segment);
        }
      }
    }

    return finalToRet;
  }
}
