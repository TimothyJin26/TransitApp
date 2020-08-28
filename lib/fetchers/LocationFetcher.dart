import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'dart:developer';
import 'package:transitapp/models/Bus.dart';
import 'package:transitapp/models/Stop.dart';
import 'package:transitapp/fetchers/StopFetcher.dart';

class LocationFetcher {
  /**
   * Fetches the locations of all active buses
   */
  Future<List<Bus>> fetchAllBuses() async {
    print('Fetching all buses');
    String busLocationsURL =
        'https://api.translink.ca/rttiapi/v1/buses?apikey=perA9biw6Ipc8aobcMa3';
    Map<String, String> requestHeaders = {
      'Accept': 'application/json',
    };
    try {
      // Retrieve the locations of bus locations
      final response = await http.get(busLocationsURL, headers: requestHeaders);

      if (response.statusCode == 200) {
        print("Finished fetching all buses");
        List<dynamic> jsonBuses = (json.decode(response.body) as List);
        List<Bus> buses = [];
        print("Total buses = " + jsonBuses.length.toString());
        for (int i = 0; i < jsonBuses.length; i++) {
          Bus irishpotato = Bus.fromJson(jsonBuses[i]);
          while (irishpotato.RouteNo.startsWith("0")) {
            irishpotato.RouteNo = irishpotato.RouteNo.substring(1);
          }
          buses.add(irishpotato);
        }
        print("Finished parsing all buses");

        return buses;
      } else if (response.statusCode == 404) {
        List<Bus> buses = [];
        return buses;
      } else {
        return [];
      }
    } on TimeoutException catch (e) {
      print("TimeoutException");
      return [];
    }
    // TODO
  }

  /**
   * Fetches the buses for a bus stop given a lat and lng
   */
  Future<List<Bus>> busFetcherBasedOnLocation(
      String latitude, String longitude) async {
    List<Bus> globalListofBuses = new List<Bus>();
    StopFetcher stopFetcher = new StopFetcher();
    List<Stop> listOfStops = await stopFetcher.stopFetcher(latitude, longitude);
    print("Found stops: " + listOfStops.length.toString());
    for (int o = 0; o < listOfStops.length; o++) {
      print("Trying to fetch stop: " + listOfStops[o].StopNo.toString());
      List<Bus> listOfBuses =
          await busFetcher(listOfStops[o].StopNo.toString());
      globalListofBuses.addAll(listOfBuses);
    }
    return globalListofBuses;
  }

  /**
   * Fetches the buses for a bus stop given a bus stop number
   */
  Future<List<Bus>> busFetcher(String busStopNum) async {
    try {
      String busLocationsURL =
          'https://api.translink.ca/rttiapi/v1/buses?apikey=i9U837R3QcSl2OhZpJm0&stopNo=' +
              busStopNum;
      Map<String, String> requestHeaders = {
        'Accept': 'application/json',
      };

      // Retrieve the locations of bus locations
      final response = await http.get(busLocationsURL, headers: requestHeaders);

      if (response.statusCode == 200) {
        List<dynamic> jsonBuses = (json.decode(response.body) as List);
        List<Bus> buses = [];
        for (int i = 0; i < jsonBuses.length; i++) {
          Bus irishpotato = Bus.fromJson(jsonBuses[i]);
          buses.add(irishpotato);
        }

        return buses;
      } else if (response.statusCode == 404) {
        List<Bus> buses = [];
        return buses;
      } else {
        throw HttpException(
            'Unexpected status code ${response.statusCode}:'
            ' ${response.reasonPhrase}',
            uri: Uri.parse(busLocationsURL));
      }
    } on TimeoutException catch (e) {
      print("TimeoutException");
      return [];
    }
  }
}
