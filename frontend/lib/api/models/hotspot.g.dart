// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hotspot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HotspotProperties _$HotspotPropertiesFromJson(Map<String, dynamic> json) =>
    HotspotProperties(
      density: (json['density'] as num).toDouble(),
    );

Map<String, dynamic> _$HotspotPropertiesToJson(HotspotProperties instance) =>
    <String, dynamic>{
      'density': instance.density,
    };

HotspotGeometry _$HotspotGeometryFromJson(Map<String, dynamic> json) =>
    HotspotGeometry(
      type: json['type'] as String,
      coordinates: (json['coordinates'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$HotspotGeometryToJson(HotspotGeometry instance) =>
    <String, dynamic>{
      'type': instance.type,
      'coordinates': instance.coordinates,
    };

HotspotFeature _$HotspotFeatureFromJson(Map<String, dynamic> json) =>
    HotspotFeature(
      type: json['type'] as String,
      geometry:
          HotspotGeometry.fromJson(json['geometry'] as Map<String, dynamic>),
      properties: HotspotProperties.fromJson(
          json['properties'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$HotspotFeatureToJson(HotspotFeature instance) =>
    <String, dynamic>{
      'type': instance.type,
      'geometry': instance.geometry,
      'properties': instance.properties,
    };
