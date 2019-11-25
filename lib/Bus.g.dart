// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Bus.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Bus _$BusFromJson(Map<String, dynamic> json) {
  return Bus(
      VehicleNo: json['VehicleNo'] as String,
      TripId: json['TripId'] as int,
      RouteNo: json['RouteNo'] as String,
      Direction: json['Direction'] as String,
      Destination: json['Destination'] as String,
      Pattern: json['Pattern'] as String,
      Latitude: (json['Latitude'] as num)?.toDouble(),
      Longitude: (json['Longitude'] as num)?.toDouble(),
      RecordedTime: json['RecordedTime'] as String,
      RouteMap: json['RouteMap'] == null
          ? null
          : RouteLink.fromJson(json['RouteMap'] as Map<String, dynamic>));
}

Map<String, dynamic> _$BusToJson(Bus instance) => <String, dynamic>{
      'VehicleNo': instance.VehicleNo,
      'TripId': instance.TripId,
      'RouteNo': instance.RouteNo,
      'Direction': instance.Direction,
      'Destination': instance.Destination,
      'Pattern': instance.Pattern,
      'Latitude': instance.Latitude,
      'Longitude': instance.Longitude,
      'RecordedTime': instance.RecordedTime,
      'RouteMap': instance.RouteMap
    };
