import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/SingleDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/models/Trip.dart';

class BusAtSingleStopFetcher {
  Future<List<BothDirectionRouteWithTrips>> busAtSingleStopFetcher(
      Stop stop, String busStopNum) async {
    final List<BothDirectionRouteWithTrips> routeTrips = [];

    final String stopLocationsURL =
        'https://api.translink.ca/rttiapi/v1/stops/$busStopNum/estimates?apikey=perA9biw6Ipc8aobcMa3';
    final Map<String, String> requestHeaders = {'Accept': 'application/json'};

    try {
      final response = await http
          .get(Uri.parse(stopLocationsURL), headers: requestHeaders)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return [];

      final List<dynamic> listOfTripsJson =
          json.decode(response.body) as List;

      for (final dynamic item in listOfTripsJson) {
        final SingleDirectionRouteWithTrips route =
            SingleDirectionRouteWithTrips.fromJson(
                item as Map<String, dynamic>);

        for (final Trip t in route.Schedules ?? []) {
          if (stop.AtStreet == null || stop.OnStreet == null) {
            t.nextStop = stop.Name;
          } else {
            t.nextStop = '${stop.AtStreet} and \n${stop.OnStreet}';
          }
          t.StopNo = stop.StopNo.toString();
        }

        final String routeNo = route.RouteNo ?? '';
        final int existingIndex =
            routeTrips.indexWhere((r) => r.RouteNo == routeNo);
        if (existingIndex < 0) {
          routeTrips.add(
              BothDirectionRouteWithTrips(routeNo, route.Schedules ?? []));
        } else {
          routeTrips[existingIndex].Trips.addAll(route.Schedules ?? []);
        }
      }
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }

    return routeTrips;
  }
}
