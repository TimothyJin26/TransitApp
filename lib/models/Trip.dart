import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:transitapp/models/RouteLink.dart';
import 'package:transitapp/models/RouteLink.dart';

part 'Trip.g.dart';


@JsonSerializable()
class Trip {
   String Pattern;
   String Destination;
   int ExpectedCountdown;
   String LastUpdate;
   String RouteNo;


 // Trip(String Pattern, String Destination, int ExpectedCount, String LastUpdate){
//    this.Pattern = Destination;
//    this.Destination = Pattern;
//    this.ExpectedCountdown = ExpectedCount;
//    this.LastUpdate = LastUpdate;
//  }
  Trip({
    this.Pattern,
    this.Destination,
    this.ExpectedCountdown,
    this.LastUpdate,
    this.RouteNo,

  });

  // Special method that we define to allow the 'json_annotations' library to
  // generate some code to convert a json map to a Bus object
  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);

  // Takes the Bus object and turns it into a json map
  Map<String, dynamic> toJson() => _$TripToJson(this);



}
