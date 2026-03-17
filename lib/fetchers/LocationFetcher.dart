import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:transitapp/models/Bus.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/fetchers/StopFetcher.dart';

class LocationFetcher {
  /// Fetches the locations of all active buses
  Future<List<Bus>> fetchAllBuses() async {
    const String busLocationsURL =
        'https://api.translink.ca/rttiapi/v1/buses?apikey=perA9biw6Ipc8aobcMa3';
    final Map<String, String> requestHeaders = {'Accept': 'application/json'};
    try {
      final response = await http.get(
        Uri.parse(busLocationsURL),
        headers: requestHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonBuses = json.decode(response.body) as List;
        final List<Bus> buses = [];
        for (final dynamic item in jsonBuses) {
          final Bus bus = Bus.fromJson(item as Map<String, dynamic>);
          while (bus.RouteNo != null && bus.RouteNo!.startsWith('0')) {
            bus.RouteNo = bus.RouteNo!.substring(1);
          }
          buses.add(bus);
        }
        return buses;
      } else {
        return [];
      }
    } on TimeoutException {
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches the buses for a bus stop given a lat and lng
  Future<List<Bus>> busFetcherBasedOnLocation(
      String latitude, String longitude) async {
    final List<Bus> globalListofBuses = [];
    final StopFetcher stopFetcher = StopFetcher();
    final List<Stop> listOfStops =
        await stopFetcher.stopFetcher(latitude, longitude);
    for (final Stop stop in listOfStops) {
      final List<Bus> listOfBuses =
          await busFetcher(stop.StopNo.toString());
      globalListofBuses.addAll(listOfBuses);
    }
    return globalListofBuses;
  }

  /// Fetches the buses for a bus stop given a bus stop number
  Future<List<Bus>> busFetcher(String busStopNum) async {
    final String busLocationsURL =
        'https://api.translink.ca/rttiapi/v1/buses?apikey=i9U837R3QcSl2OhZpJm0&stopNo=$busStopNum';
    final Map<String, String> requestHeaders = {'Accept': 'application/json'};
    try {
      final response = await http.get(
        Uri.parse(busLocationsURL),
        headers: requestHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonBuses = json.decode(response.body) as List;
        final List<Bus> buses = [];
        for (final dynamic item in jsonBuses) {
          buses.add(Bus.fromJson(item as Map<String, dynamic>));
        }
        return buses;
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
