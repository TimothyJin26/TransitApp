import 'package:json_annotation/json_annotation.dart';

part 'Trip.g.dart';

@JsonSerializable()
class Trip {
  String? nextStop;
  String? Pattern;
  String? Destination;
  int? ExpectedCountdown;
  String? LastUpdate;
  String? RouteNo;
  String? StopNo;
  String? ExpectedLeaveTime;

  Trip({
    this.Pattern,
    this.Destination,
    this.ExpectedCountdown,
    this.LastUpdate,
    this.RouteNo,
    this.ExpectedLeaveTime,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);
  Map<String, dynamic> toJson() => _$TripToJson(this);
}
