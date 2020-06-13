// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Stop.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Stop _$StopFromJson(Map<String, dynamic> json) {
  return Stop(
      StopNo: json['StopNo'] as int,
      Name: json['Name'] as String,
      BayNo: json['BayNo'] as String,
      City: json['City'] as String,
      OnStreet: json['OnStreet'] as String,
      AtStreet: json['AtStreet'] as String,
      Latitude: (json['Latitude'] as num)?.toDouble(),
      Longitude: (json['Longitude'] as num)?.toDouble(),
      WheelchairAccess: json['WheelchairAccess'] as int,
      Distance: json['Distance'] as int,
      Routes: json['Routes'] as String);
}

Map<String, dynamic> _$StopToJson(Stop instance) => <String, dynamic>{
      'StopNo': instance.StopNo,
      'Name': instance.Name,
      'BayNo': instance.BayNo,
      'City': instance.City,
      'OnStreet': instance.OnStreet,
      'AtStreet': instance.AtStreet,
      'Latitude': instance.Latitude,
      'Longitude': instance.Longitude,
      'WheelchairAccess': instance.WheelchairAccess,
      'Distance': instance.Distance,
      'Routes': instance.Routes
    };
