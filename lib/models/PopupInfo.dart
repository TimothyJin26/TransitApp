import 'package:transitapp/models/Trip.dart';

class BothDirectionRouteWithTrips {
  BothDirectionRouteWithTrips(String RouteNumber, List<Trip> trips) {
    this.RouteNo = RouteNumber;
    this.Trips = trips;
  }

  String RouteNo;
  List<Trip> Trips;
}
