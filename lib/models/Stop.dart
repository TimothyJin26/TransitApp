import 'package:json_annotation/json_annotation.dart';

// Generate using: flutter packages pub run build_runner build
part 'Stop.g.dart';

/// Represents a stop returned from Translink
//  {
//    "StopNo": 60153,
//    "Name": "SURREY CENTRAL STN BAY 15",
//    "BayNo": "15",
//    "City": "SURREY",
//    "OnStreet": "SURREY CENTRAL STN",
//    "AtStreet": "BAY 15",
//    "Latitude": 49.188245,
//    "Longitude": -122.849535,
//    "WheelchairAccess": 1,
//    "Distance": 71,
//    "Routes": ""
//  }
@JsonSerializable()
class Stop {
  Stop({
    this.StopNo,
    this.Name,
    this.BayNo,
    this.City,
    this.OnStreet,
    this.AtStreet,
    this.Latitude,
    this.Longitude,
    this.WheelchairAccess,
    this.Distance,
    this.Routes,
  });

  factory Stop.fromJson(Map<String, dynamic> json) => _$StopFromJson(json);
  Map<String, dynamic> toJson() => _$StopToJson(this);

  int? StopNo;
  String? Name;
  String? BayNo;
  String? City;
  String? OnStreet;
  String? AtStreet;
  double? Latitude;
  double? Longitude;
  int? WheelchairAccess;
  int? Distance;
  String? Routes;
}
