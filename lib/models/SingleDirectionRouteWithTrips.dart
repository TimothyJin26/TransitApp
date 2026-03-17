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

  factory SingleDirectionRouteWithTrips.fromJson(Map<String, dynamic> json) =>
      _$SingleDirectionRouteWithTripsFromJson(json);
  Map<String, dynamic> toJson() =>
      _$SingleDirectionRouteWithTripsToJson(this);

  final String? RouteNo;
  final String? RouteName;
  final String? Direction;
  final List<Trip>? Schedules;
}
