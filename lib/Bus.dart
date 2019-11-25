import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/RouteLink.dart';
import 'RouteLink.dart';


part 'Bus.g.dart';

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

  // Special method that we define to allow the 'json_annotations' library to
  // generate some code to convert a json map to a Bus object
  factory Bus.fromJson(Map<String, dynamic> json) => _$BusFromJson(json);

  // Takes the Bus object and turns it into a json map
  Map<String, dynamic> toJson() => _$BusToJson(this);

  final String VehicleNo;
  final int TripId;
  final String RouteNo;
  final String Direction;
  final String Destination;
  final String Pattern;
  final double Latitude;
  final double Longitude;
  final String RecordedTime;
  final RouteLink RouteMap;
}
