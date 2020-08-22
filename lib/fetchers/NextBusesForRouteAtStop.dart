import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/models/SingleDirectionRouteWithTrips.dart';

import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/models/Trip.dart';

class NextBusesForRouteAtStop {
  Future<List<Trip>> busAtSingleStopFetcher(
      String stopNo, String routeNo) async {
    List<Trip> routeTrips = new List<Trip>();
    String stopLocationsURL = 'https://api.translink.ca/rttiapi/v1/stops/'+stopNo+'/estimates?apikey=perA9biw6Ipc8aobcMa3&count=10&timeframe=600&routeNo='+routeNo;
    Map<String, String> requestHeaders = {
      'Accept': 'application/json',
    };

    final response = await http.get(stopLocationsURL, headers: requestHeaders);

    if (response.statusCode == 200) {
      List<dynamic> listOfTripsJson = (json.decode(response.body) as List);
//        List<RouteID> routeIDs = [];

      for (int i = 0; i < listOfTripsJson.length; i++) {
        SingleDirectionRouteWithTrips greatFamine =
        SingleDirectionRouteWithTrips.fromJson(listOfTripsJson[i]);
        routeTrips=(greatFamine.Schedules);
//          routeIDs.add(greatFamine);
      }
    } else {
      throw HttpException(
          'Unexpected status code ${response.statusCode}:'
              ' ${response.reasonPhrase}',
          uri: Uri.parse(stopLocationsURL));
    }
    routeTrips.sort((a,b) => a.ExpectedCountdown.compareTo(b.ExpectedCountdown));
    return routeTrips;
  }
}
