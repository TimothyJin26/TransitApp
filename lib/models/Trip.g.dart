// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Trip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Trip _$TripFromJson(Map<String, dynamic> json) {
  return Trip(
      Pattern: json['Pattern'] as String,
      Destination: json['Destination'] as String,
      ExpectedCountdown: json['ExpectedCountdown'] as int,
      LastUpdate: json['LastUpdate'] as String,
      RouteNo: json['RouteNo'] as String,
      ExpectedLeaveTime: json['ExpectedLeaveTime'] as String)
    ..nextStop = json['nextStop'] as String
    ..StopNo = json['StopNo'] as String;
}

Map<String, dynamic> _$TripToJson(Trip instance) => <String, dynamic>{
      'nextStop': instance.nextStop,
      'Pattern': instance.Pattern,
      'Destination': instance.Destination,
      'ExpectedCountdown': instance.ExpectedCountdown,
      'LastUpdate': instance.LastUpdate,
      'RouteNo': instance.RouteNo,
      'StopNo': instance.StopNo,
      'ExpectedLeaveTime': instance.ExpectedLeaveTime
    };
