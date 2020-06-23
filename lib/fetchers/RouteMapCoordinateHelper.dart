import 'dart:convert';
import 'dart:io';
import 'package:xml/xml.dart' as xml;
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteMapCoordinateHelper {
  String url;

  Future<List<LatLng>> getLatLng(String url) async {
    List<LatLng> toRet = [];
    this.url = url;
    final response = await http.get(url);
    if (response.statusCode == 200) {
      var bytes = response.bodyBytes;

      // Decode the Zip file
      final archive = ZipDecoder().decodeBytes(bytes);

      // Extract the contents of the Zip archive to disk.
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          String bar = utf8.decode(data);
          print(bar.toString());
          final document = xml.parse(bar);
          Iterable<xml.XmlElement> coordinateList = document.findAllElements('coordinates');
          print(coordinateList.toString());
          print(url.toString());
          for(xml.XmlElement e in coordinateList){
            var stringList = e.text.split("0.0 ");
            for(String s in stringList){
              var list = s.split(",");
              var kat = list[1];
              var lng = list[0];
              print(double.parse(list[0].substring(1,10)).toString()+"           ASDFGHJNBVCDSERTYUJKMNBVCXDFGHJMNB VCXDFGHJKMN BVCXSDFGTHJKM NBVCXDFRTGYHJMNB VCDFRTYHJNB VCXDFRTYUKMN BVCFRTYUKMNBVFGHJ POTATO");
              toRet.add(new LatLng(double.parse(list[1]), double.parse(list[0])));
            }
          }
        }
      }
    }
    return toRet;
  }
}
