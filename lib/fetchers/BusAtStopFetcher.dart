import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/models/SingleDirectionRouteWithTrips.dart';

import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/models/Trip.dart';

class BusAtStopFetcher {

  Future<List<BothDirectionRouteWithTrips>> busFetcher(List<Stop> stopList, double Lat, double Lng) async {
    List<BothDirectionRouteWithTrips> routeTrips = new List<BothDirectionRouteWithTrips>(); // Gets stops that are closest to the user
    List<Stop> shortestDistance = new List<Stop>();
    stopList.sort((a, b) {
      var distanceLatA = pow(a.Latitude-Lat,2);
      var distanceLatB = pow(b.Latitude-Lat,2);
      var distanceLongA = pow(a.Longitude-Lng,2);
      var distanceLongB = pow(b.Longitude-Lng,2);
      var distanceA = sqrt(distanceLatA+distanceLongA);
      var distanceB = sqrt(distanceLatB+distanceLongB);
      return distanceA.compareTo(distanceB);
    });

    shortestDistance = stopList.sublist(0,6);
    //  Go through every stop to fetch the next buses
    print("thirty one (31) trente et un (31)"+stopList.toString());
    for(Stop stop in shortestDistance){
      print("Locatione                           "+stop.StopNo.toString()+" "+stop.Latitude.toString());
      String stopLocationsURL = 'https://api.translink.ca/rttiapi/v1/stops/'+ stop.StopNo.toString() +'/estimates?apikey=perA9biw6Ipc8aobcMa3';
      Map<String, String> requestHeaders = {
        'Accept': 'application/json',
      };

      final response = await http.get(stopLocationsURL, headers: requestHeaders);

      if (response.statusCode == 200) {
        print(stop.toJson().toString());
        List<dynamic> jsonStops = (json.decode(response.body) as List);
//        List<RouteID> routeIDs = [];
        print("ici est un error");
        for (int i = 0; i < jsonStops.length; i++) {
          // Go through each of the next buses for the stop
          SingleDirectionRouteWithTrips routeObjects = SingleDirectionRouteWithTrips.fromJson(jsonStops[i]);
          print(routeObjects.Schedules.toString());
          for(Trip t in routeObjects.Schedules){
            t.nextStop = stop.AtStreet+" and \n"+stop.OnStreet;
          }

          List<String> list = new List<String>();
          for(BothDirectionRouteWithTrips routeTrip in routeTrips){
            list.add(routeTrip.RouteNo);
          }
          print(routeObjects.RouteNo);
          if(!list.contains(routeObjects.RouteNo)){
            print("pomme de terre");
            routeTrips.add(new BothDirectionRouteWithTrips(routeObjects.RouteNo, routeObjects.Schedules));

          } else {
            print(".é.,ééééé");
            for(BothDirectionRouteWithTrips routeTrip in routeTrips){
              if(routeTrip.RouteNo == routeObjects.RouteNo){
                routeTrip.Trips.addAll(routeObjects.Schedules);
                break;
              }
            }
          }
//          routeIDs.add(irishplenty);
        }
      } else {
        throw HttpException(
            'Unexpected status code ${response.statusCode}:'
                ' ${response.reasonPhrase}',
            uri: Uri.parse(stopLocationsURL));
      }
    }
  return routeTrips;

  }
}

