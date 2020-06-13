import 'package:json_annotation/json_annotation.dart';

import 'Trip.dart';

part 'SingleDirectionRouteWithTrips.g.dart';


@JsonSerializable()
class SingleDirectionRouteWithTrips {
  SingleDirectionRouteWithTrips({
    this.RouteNo,
    this.Direction,
    this.RouteName,
    this.Schedules,

  });

  // Special method that we define to allow the 'json_annotations' library to
  // generate some code to convert a json map to a Bus object
  factory SingleDirectionRouteWithTrips.fromJson(Map<String, dynamic> json) => _$SingleDirectionRouteWithTripsFromJson(json);

  // Takes the Bus object and turns it into a json map
  Map<String, dynamic> toJson() => _$SingleDirectionRouteWithTripsToJson(this);


  final String RouteNo;
  final String RouteName;
  final String Direction;
  final List<Trip> Schedules;
}
