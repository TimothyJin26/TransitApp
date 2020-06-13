import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';

part 'RouteLink.g.dart';

@JsonSerializable()
class RouteLink {

  final String Href;

  RouteLink({
    this.Href,
  });

  // Special method that we define to allow the 'json_annotations' library to
  // generate some code to convert a json map to a Bus object
  factory RouteLink.fromJson(Map<String, dynamic> json) => _$RouteLinkFromJson(json);

  // Takes the Bus object and turns it into a json map
  Map<String, dynamic> toJson() => _$RouteLinkToJson(this);

}
