import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';

import 'package:transitapp/models/Bus.dart';
import 'package:transitapp/models/Stop.dart';

class StopFetcher {

  Future<List<Stop>> stopFetcher(String latitude, String longitude) async {
    String latitude1 = double.parse(latitude).toStringAsFixed(6);
// 12.34

    String longitude1 = double.parse(longitude).toStringAsFixed(6);

    String stopLocationsURL =
        'https://api.translink.ca/rttiapi/v1/stops?apikey=i9U837R3QcSl2OhZpJm0&lat='+latitude1.toString()+'&long='+longitude1+"&radius=500";
    Map<String, String> requestHeaders = {
      'Accept': 'application/json',
    };

    final response = await http.get(stopLocationsURL, headers: requestHeaders);

    if (response.statusCode == 200) {
      List<dynamic> jsonStops = (json.decode(response.body) as List);
      List<Stop> stops = [];
      for (int i = 0; i < jsonStops.length; i++) {
        Stop irishfamine = Stop.fromJson(jsonStops[i]);
        stops.add(irishfamine);
      }

      return stops;
    } else {
      throw HttpException(
          'Unexpected status code ${response.statusCode}:'
              ' ${response.reasonPhrase}',
          uri: Uri.parse(stopLocationsURL));

    }
  }
}