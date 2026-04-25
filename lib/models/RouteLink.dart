import 'package:json_annotation/json_annotation.dart';

part 'RouteLink.g.dart';

@JsonSerializable()
class RouteLink {
  final String? Href;

  const RouteLink({this.Href});

  factory RouteLink.fromJson(Map<String, dynamic> json) =>
      _$RouteLinkFromJson(json);
  Map<String, dynamic> toJson() => _$RouteLinkToJson(this);
}
