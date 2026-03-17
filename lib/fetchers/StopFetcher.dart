import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:transitapp/models/Stop.dart';

class StopFetcher {
  Future<List<Stop>> stopFetcher(String latitude, String longitude) async {
    final String latitude1 = double.parse(latitude).toStringAsFixed(6);
    final String longitude1 = double.parse(longitude).toStringAsFixed(6);

    final String stopLocationsURL =
        'https://api.translink.ca/rttiapi/v1/stops?apikey=i9U837R3QcSl2OhZpJm0'
        '&lat=$latitude1&long=$longitude1&radius=500';
    final Map<String, String> requestHeaders = {'Accept': 'application/json'};
    try {
      final response = await http.get(
        Uri.parse(stopLocationsURL),
        headers: requestHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonStops = json.decode(response.body) as List;
        final List<Stop> stops = [];
        for (final dynamic item in jsonStops) {
          stops.add(Stop.fromJson(item as Map<String, dynamic>));
        }
        return stops;
      } else {
        return [];
      }
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }
  }
}
