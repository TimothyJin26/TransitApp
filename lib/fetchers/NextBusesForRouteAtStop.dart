import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:transitapp/models/SingleDirectionRouteWithTrips.dart';
import 'package:transitapp/models/Trip.dart';

class NextBusesForRouteAtStop {
  Future<List<Trip>> busAtSingleStopFetcher(
      String stopNo, String routeNo) async {
    final String url =
        'https://api.translink.ca/rttiapi/v1/stops/$stopNo/estimates'
        '?apikey=perA9biw6Ipc8aobcMa3&count=10&timeframe=600&routeNo=$routeNo';
    final Map<String, String> requestHeaders = {'Accept': 'application/json'};

    try {
      final response =
          await http.get(Uri.parse(url), headers: requestHeaders);

      if (response.statusCode != 200) return [];

      final List<dynamic> listOfTripsJson =
          json.decode(response.body) as List;

      List<Trip> routeTrips = [];
      for (final dynamic item in listOfTripsJson) {
        final SingleDirectionRouteWithTrips route =
            SingleDirectionRouteWithTrips.fromJson(
                item as Map<String, dynamic>);
        routeTrips = route.Schedules ?? [];
      }

      routeTrips.sort((a, b) =>
          (a.ExpectedCountdown ?? 0).compareTo(b.ExpectedCountdown ?? 0));
      return routeTrips;
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }
  }
}
