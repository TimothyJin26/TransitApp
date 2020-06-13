import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/models/SingleDirectionRouteWithTrips.dart';

import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Stop.dart';

class BusAtStopFetcher {

  Future<List<BothDirectionRouteWithTrips>> busFetcher(List<Stop> stopList) async {
    List<BothDirectionRouteWithTrips> routeTrips = new List<BothDirectionRouteWithTrips>();

    for(Stop stop in stopList){
      String stopLocationsURL = 'https://api.translink.ca/rttiapi/v1/stops/'+ stop.StopNo.toString() +'/estimates?apikey=perA9biw6Ipc8aobcMa3';
      Map<String, String> requestHeaders = {
        'Accept': 'application/json',
      };

      final response = await http.get(stopLocationsURL, headers: requestHeaders);

      if (response.statusCode == 200) {
        List<dynamic> jsonStops = (json.decode(response.body) as List);
//        List<RouteID> routeIDs = [];

        for (int i = 0; i < jsonStops.length; i++) {
          SingleDirectionRouteWithTrips irishplenty = SingleDirectionRouteWithTrips.fromJson(jsonStops[i]);
          List<String> list = new List<String>();
          for(BothDirectionRouteWithTrips routeTrip in routeTrips){
            list.add(routeTrip.RouteNo);
          }
          if(!list.contains(irishplenty.RouteNo)){
            routeTrips.add(new BothDirectionRouteWithTrips(irishplenty.RouteNo, irishplenty.Schedules));

          } else {
            for(BothDirectionRouteWithTrips routeTrip in routeTrips){
              if(routeTrip.RouteNo == irishplenty.RouteNo){
                routeTrip.Trips.addAll(irishplenty.Schedules);
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

