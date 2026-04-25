import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/models/RouteLink.dart';

part 'Bus.g.dart';

/// Represents a bus object returned from Translink
//  {
//    "VehicleNo": "15015",
//    "TripId": 10631538,
//    "RouteNo": "049",
//    "Direction": "WEST",
//    "Destination": "UBC",
//    "Pattern": "WB1",
//    "Latitude": 49.264817,
//    "Longitude": -123.244083,
//    "RecordedTime": "10:25:36 pm",
//    "RouteMap":{
//      "Href": "https://nb.translink.ca/geodata/049.kmz"
//    }
//  }
@JsonSerializable()
class Bus {
  Bus({
    this.VehicleNo,
    this.TripId,
    this.RouteNo,
    this.Direction,
    this.Destination,
    this.Pattern,
    this.Latitude,
    this.Longitude,
    this.RecordedTime,
    this.RouteMap,
  });

  factory Bus.fromJson(Map<String, dynamic> json) => _$BusFromJson(json);
  Map<String, dynamic> toJson() => _$BusToJson(this);

  final String? VehicleNo;
  final int? TripId;
  String? RouteNo;
  final String? Direction;
  final String? Destination;
  final String? Pattern;
  final double? Latitude;
  final double? Longitude;
  final String? RecordedTime;
  final RouteLink? RouteMap;
}
