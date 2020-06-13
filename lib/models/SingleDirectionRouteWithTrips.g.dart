// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SingleDirectionRouteWithTrips.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SingleDirectionRouteWithTrips _$SingleDirectionRouteWithTripsFromJson(
    Map<String, dynamic> json) {
  return SingleDirectionRouteWithTrips(
      RouteNo: json['RouteNo'] as String,
      Direction: json['Direction'] as String,
      RouteName: json['RouteName'] as String,
      Schedules: (json['Schedules'] as List)
          ?.map((e) =>
              e == null ? null : Trip.fromJson(e as Map<String, dynamic>))
          ?.toList());
}

Map<String, dynamic> _$SingleDirectionRouteWithTripsToJson(
        SingleDirectionRouteWithTrips instance) =>
    <String, dynamic>{
      'RouteNo': instance.RouteNo,
      'RouteName': instance.RouteName,
      'Direction': instance.Direction,
      'Schedules': instance.Schedules
    };
