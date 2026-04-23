import 'package:flutter/services.dart' show rootBundle;
import 'package:transitapp/models/Stop.dart';

Future<List<Stop>> loadStopsFromAsset() async {
  final String csv = await rootBundle.loadString('assets/stops.txt');
  final List<String> lines = csv.split('\n');
  final List<String> header = lines[0].split(',');
  final int stopNoCol = header.indexOf('stop_code');
  final int nameCol = header.indexOf('stop_name');
  final int lonCol = header.indexOf('stop_lon');
  final int latCol = header.indexOf('stop_lat');
  lines.removeAt(0);

  final List<Stop> stops = [];
  for (final String line in lines) {
    final List<String> cols = line.split(',');
    final Stop stop = Stop();
    try {
      stop.StopNo = int.parse(cols[stopNoCol]);
    } catch (_) {
      continue;
    }
    stop.Name = cols[nameCol];
    stop.Longitude = double.parse(cols[lonCol]);
    stop.Latitude = double.parse(cols[latCol]);
    if (cols[nameCol].contains('@')) {
      stop.OnStreet = cols[nameCol].split('@')[0];
      stop.AtStreet = cols[nameCol].split('@')[1];
    } else {
      stop.OnStreet = cols[nameCol];
      stop.AtStreet = '';
    }
    stops.add(stop);
  }
  return stops;
}
