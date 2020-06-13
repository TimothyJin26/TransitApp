import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/models/RouteLink.dart';
import 'package:transitapp/models/RouteLink.dart';

part 'Trip.g.dart';


@JsonSerializable()
class Trip {
  Trip({
    this.Pattern,
    this.Destination,
    this.ExpectedCountdown,
    this.LastUpdate,

  });

  // Special method that we define to allow the 'json_annotations' library to
  // generate some code to convert a json map to a Bus object
  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);

  // Takes the Bus object and turns it into a json map
  Map<String, dynamic> toJson() => _$TripToJson(this);


  final String Pattern;
  final String Destination;
  final String ExpectedCountdown;
  final String LastUpdate;
}
