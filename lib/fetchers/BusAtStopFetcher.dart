import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:transitapp/models/BothDirectionRouteWithTrips.dart';
import 'package:transitapp/models/SingleDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/models/Trip.dart';

class BusAtStopFetcher {
  Future<List<BothDirectionRouteWithTrips>> busFetcher(
      List<Stop> stopList, double lat, double lng) async {
    final List<BothDirectionRouteWithTrips> routeTrips = [];

    // Sort stops by distance and take the 6 closest
    stopList.sort((a, b) {
      final distanceA = sqrt(pow((a.Latitude ?? 0) - lat, 2) +
          pow((a.Longitude ?? 0) - lng, 2));
      final distanceB = sqrt(pow((b.Latitude ?? 0) - lat, 2) +
          pow((b.Longitude ?? 0) - lng, 2));
      return distanceA.compareTo(distanceB);
    });

    final List<Stop> shortestDistance =
        stopList.sublist(0, min(stopList.length, 6));

    final Map<String, String> requestHeaders = {'Accept': 'application/json'};

    // Fire all requests in parallel
    final List<Future<http.Response>> futures = shortestDistance
        .map((stop) => http.get(
              Uri.parse(
                'https://api.translink.ca/rttiapi/v1/stops/'
                '${stop.StopNo}/estimates?apikey=perA9biw6Ipc8aobcMa3',
              ),
              headers: requestHeaders,
            ))
        .toList();

    for (int counter = 0; counter < futures.length; counter++) {
      final response = await futures[counter];
      if (response.statusCode == 200) {
        final List<dynamic> jsonStops = json.decode(response.body) as List;
        for (final dynamic item in jsonStops) {
          final SingleDirectionRouteWithTrips routeObjects =
              SingleDirectionRouteWithTrips.fromJson(
                  item as Map<String, dynamic>);

          final Stop currentStop = shortestDistance[counter];
          final List<Trip> validSchedules = [];
          for (final Trip t in routeObjects.Schedules ?? []) {
            if ((t.ExpectedCountdown ?? 0) < 0) continue;
            if (currentStop.AtStreet == null || currentStop.OnStreet == null) {
              t.nextStop = currentStop.Name;
            } else {
              final String onStreet = currentStop.OnStreet!.trim();
              final int spaceIdx = onStreet.indexOf(' ');
              t.nextStop =
                  '${currentStop.AtStreet!.trim()} and \n${spaceIdx >= 0 ? onStreet.substring(spaceIdx + 1) : onStreet}';
            }
            t.StopNo = currentStop.StopNo.toString();
            validSchedules.add(t);
          }

          final String routeNo = routeObjects.RouteNo ?? '';
          final int existingIndex =
              routeTrips.indexWhere((r) => r.RouteNo == routeNo);
          if (existingIndex < 0) {
            routeTrips.add(BothDirectionRouteWithTrips(routeNo, validSchedules));
          } else {
            routeTrips[existingIndex].Trips.addAll(validSchedules);
          }
        }
      }
    }

    return routeTrips;
  }
}
