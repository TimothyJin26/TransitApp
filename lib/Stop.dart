import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/RouteLink.dart';
import 'RouteLink.dart';

// Generate using: flutter packages pub run build_runner build
part 'Stop.g.dart';

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

  // Special method that we define to allow the 'json_annotations' library to
  // generate some code to convert a json map to a Bus object
  factory Stop.fromJson(Map<String, dynamic> json) => _$StopFromJson(json);

  // Takes the Bus object and turns it into a json map
  Map<String, dynamic> toJson() => _$StopToJson(this);

  final int StopNo;
  final String Name;
  final String BayNo;
  final String City;
  final String OnStreet;
  final String AtStreet;
  final double Latitude;
  final double Longitude;
  final int WheelchairAccess;
  final int Distance;
  final String Routes;
}
