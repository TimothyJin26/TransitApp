import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/models/SingleDirectionRouteWithTrips.dart';

import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/models/Trip.dart';

class BusAtStopFetcher {
  Future<List<BothDirectionRouteWithTrips>> busFetcher(
      List<Stop> stopList, double Lat, double Lng) async {
    print(DateTime.now().toString() + " START OF BUS FETCHER");
    List<BothDirectionRouteWithTrips> routeTrips = new List<
        BothDirectionRouteWithTrips>(); // Gets stops that are closest to the user
    List<Stop> shortestDistance = new List<Stop>();
    stopList.sort((a, b) {
      var distanceLatA = pow(a.Latitude - Lat, 2);
      var distanceLatB = pow(b.Latitude - Lat, 2);
      var distanceLongA = pow(a.Longitude - Lng, 2);
      var distanceLongB = pow(b.Longitude - Lng, 2);
      var distanceA = sqrt(distanceLatA + distanceLongA);
      var distanceB = sqrt(distanceLatB + distanceLongB);
      return distanceA.compareTo(distanceB);
    });

    shortestDistance = stopList.sublist(0, 8);
    //  Go through every stop to fetch the next buses
    print("thirty one (31) trente et un (31)" + stopList.toString());

    List<Future<Response>> futures = [];

    for (Stop stop in shortestDistance) {
      String stopLocationsURL = 'https://api.translink.ca/rttiapi/v1/stops/' +
          stop.StopNo.toString() +
          '/estimates?apikey=perA9biw6Ipc8aobcMa3';
      Map<String, String> requestHeaders = {
        'Accept': 'application/json',
      };

      futures.add(http.get(stopLocationsURL, headers: requestHeaders));
    }
    var counter = 0;
    for(Future<Response> r in futures) {
      Response response = await r;
      if (response.statusCode == 200) {
        List<dynamic> jsonStops = (json.decode(response.body) as List);
        for (int i = 0; i < jsonStops.length; i++) {
          // Go through each of the next buses for the stop
          SingleDirectionRouteWithTrips routeObjects =
              SingleDirectionRouteWithTrips.fromJson(jsonStops[i]);
          print(routeObjects.Schedules.toString());
          for (Trip t in routeObjects.Schedules) {
            if (shortestDistance[counter].AtStreet == null||shortestDistance[counter].OnStreet == null) {
              t.nextStop = shortestDistance[counter].Name;
              t.StopNo = shortestDistance[counter].StopNo.toString();
            } else{
              t.nextStop = shortestDistance[counter].AtStreet + " and \n" + shortestDistance[counter].OnStreet;
              t.StopNo = shortestDistance[counter].StopNo.toString();
            }
          }

          List<String> list = new List<String>();
          for (BothDirectionRouteWithTrips routeTrip in routeTrips) {
            list.add(routeTrip.RouteNo);
          }
          print(routeObjects.RouteNo);
          if (!list.contains(routeObjects.RouteNo)) {
            routeTrips.add(new BothDirectionRouteWithTrips(
                routeObjects.RouteNo, routeObjects.Schedules));
          } else {
            for (BothDirectionRouteWithTrips routeTrip in routeTrips) {
              if (routeTrip.RouteNo == routeObjects.RouteNo) {
                routeTrip.Trips.addAll(routeObjects.Schedules);
                break;
              }
            }
          }
        }
      } else {
        print("Could not get info for stop " + shortestDistance[counter].StopNo.toString());
      }
      counter++;
    }

    print(DateTime.now().toString() + " END OF BUS FETCHER");
    return routeTrips;
  }
}
