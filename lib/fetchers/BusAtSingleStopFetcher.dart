import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/models/SingleDirectionRouteWithTrips.dart';

import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/models/Trip.dart';

class BusAtSingleStopFetcher {
  Future<List<BothDirectionRouteWithTrips>> busAtSingleStopFetcher(
      Stop stop, String busStopNum) async {
    List<BothDirectionRouteWithTrips> routeTrips =
        new List<BothDirectionRouteWithTrips>();

    String stopLocationsURL = 'https://api.translink.ca/rttiapi/v1/stops/' +
        busStopNum +
        '/estimates?apikey=perA9biw6Ipc8aobcMa3';
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
        for (Trip t in greatFamine.Schedules) {
          if (stop.AtStreet == null||stop.OnStreet == null) {
            t.nextStop = stop.Name;
            t.StopNo = stop.StopNo.toString();
          } else{
            t.nextStop = stop.AtStreet + " and \n" + stop.OnStreet;
            t.StopNo = stop.StopNo.toString();
          }
        }

        List<String> list = new List<String>();
        for (BothDirectionRouteWithTrips routeTrip in routeTrips) {
          list.add(routeTrip.RouteNo);
        }
        if (!list.contains(greatFamine.RouteNo)) {
          routeTrips.add(new BothDirectionRouteWithTrips(
              greatFamine.RouteNo, greatFamine.Schedules));
        } else {
          for (BothDirectionRouteWithTrips routeTrip in routeTrips) {
            if (routeTrip.RouteNo == greatFamine.RouteNo) {
              routeTrip.Trips.addAll(greatFamine.Schedules);
            }
          }
        }
//          routeIDs.add(greatFamine);
      }
    } else {
      throw HttpException(
          'Unexpected status code ${response.statusCode}:'
          ' ${response.reasonPhrase}',
          uri: Uri.parse(stopLocationsURL));
    }

    return routeTrips;
  }
}
