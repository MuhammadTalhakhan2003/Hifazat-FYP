import 'package:json_annotation/json_annotation.dart';

part 'hotspot.g.dart';

@JsonSerializable()
class HotspotProperties {
  final double density;

  HotspotProperties({required this.density});

  factory HotspotProperties.fromJson(Map<String, dynamic> json) => _$HotspotPropertiesFromJson(json);
  Map<String, dynamic> toJson() => _$HotspotPropertiesToJson(this);
}

@JsonSerializable()
class HotspotGeometry {
  final String type;
  final List<double> coordinates; // [longitude, latitude]

  HotspotGeometry({required this.type, required this.coordinates});

  factory HotspotGeometry.fromJson(Map<String, dynamic> json) => _$HotspotGeometryFromJson(json);
  Map<String, dynamic> toJson() => _$HotspotGeometryToJson(this);
}

@JsonSerializable()
class HotspotFeature {
  final String type;
  final HotspotGeometry geometry;
  final HotspotProperties properties;

  HotspotFeature({required this.type, required this.geometry, required this.properties});

  factory HotspotFeature.fromJson(Map<String, dynamic> json) => _$HotspotFeatureFromJson(json);
  Map<String, dynamic> toJson() => _$HotspotFeatureToJson(this);
}