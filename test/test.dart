import 'dart:core';

import "package:test/test.dart";
import 'package:transitapp/Bus.dart';
import 'package:transitapp/LocationFetcher.dart';

void main() {
  test("Get buses at a certain lat/lng", () async {
    LocationFetcher locationFetcher = new LocationFetcher();
    Future<List<Bus>> listOfBuses = locationFetcher.busFetcherBasedOnLocation("49.269030", "-123.248925");
    List<Bus> actualListOfBuses = (await Future.wait([listOfBuses]))[0];
    for(int i = 0; i<actualListOfBuses.length; i++){
      print(actualListOfBuses[i].RouteNo);
    }
  });


  test("Get buses at a certain bus stop", () async {
    // TODO: Create a new LocationsFetcher object
    LocationFetcher locationsFetcher = new LocationFetcher();

    // TODO: Call the busFetcher(...) method
    Future<List<Bus>> futureBuses = locationsFetcher.busFetcher("60277");
    Future<List<Bus>> futureBuses2 = locationsFetcher.busFetcher("50075");

    // TODO: Construct a list of things that we need to wait for
    // Hint: We only need to wait for one thing
    List<Future<List<Bus>>> aListOfFutureListOfBuses = new List();

    aListOfFutureListOfBuses.add(futureBuses);
    aListOfFutureListOfBuses.add(futureBuses2);

    // TODO: await for the list of things from above to finish
    List<List<Bus>> finishedFutures =
    await Future.wait(aListOfFutureListOfBuses);

    // TODO: Extract out the list of buses from finishedFutures
    // (should be the one and only element in finishedFutures)
    List<Bus> busesfrom50075 = finishedFutures[1];
    List<Bus> busesfrom60277 = finishedFutures[0];

    // TODO: use a for loop to print out the buses
    for (int i = 0; i < busesfrom50075.length; i++) {
      Bus bus = busesfrom50075[i];
      print(bus.RouteNo);
    }
    for (int i = 0; i < busesfrom60277.length; i++) {
      Bus bus = busesfrom60277[i];
      print(bus.RouteNo);
    }
  });

  test("Get buses", () async {
    LocationFetcher locationFetcher = new LocationFetcher();
    Future<List<Bus>> listOfAllBuses = locationFetcher.fetchAllBuses();
    List<Bus> actualListOfAllBuses = (await Future.wait([listOfAllBuses]))[0];
    for(int i = 0; i<actualListOfAllBuses.length; i++){
      print(actualListOfAllBuses[i].RouteNo);
    }
   });
}
