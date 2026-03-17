import 'package:transitapp/models/Trip.dart';

class BothDirectionRouteWithTrips {
  String RouteNo;
  List<Trip> Trips;

  BothDirectionRouteWithTrips(String routeNumber, List<Trip> trips)
      : RouteNo = routeNumber,
        Trips = trips;
}
