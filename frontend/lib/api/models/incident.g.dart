// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Geometry _$GeometryFromJson(Map<String, dynamic> json) => Geometry(
      type: json['type'] as String,
      coordinates: (json['coordinates'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$GeometryToJson(Geometry instance) => <String, dynamic>{
      'type': instance.type,
      'coordinates': instance.coordinates,
    };

IncidentProperties _$IncidentPropertiesFromJson(Map<String, dynamic> json) =>
    IncidentProperties(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      category: (json['category'] as num).toInt(),
      categoryName: json['category_name'] as String,
      incidentDate: DateTime.parse(json['incident_date'] as String),
      cityName: json['city_name'] as String?,
      reportedBy: (json['reported_by'] as num?)?.toInt(),
      reportedByUsername: json['reported_by_username'] as String?,
      upvotes: (json['upvotes'] as num?)?.toInt(),
      downvotes: (json['downvotes'] as num?)?.toInt(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$IncidentPropertiesToJson(IncidentProperties instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'category_name': instance.categoryName,
      'incident_date': instance.incidentDate.toIso8601String(),
      'city_name': instance.cityName,
      'reported_by': instance.reportedBy,
      'reported_by_username': instance.reportedByUsername,
      'upvotes': instance.upvotes,
      'downvotes': instance.downvotes,
      'created_at': instance.createdAt?.toIso8601String(),
    };

Incident _$IncidentFromJson(Map<String, dynamic> json) => Incident(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String,
      geometry: Geometry.fromJson(json['geometry'] as Map<String, dynamic>),
      properties: IncidentProperties.fromJson(
          json['properties'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$IncidentToJson(Incident instance) => <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'geometry': instance.geometry,
      'properties': instance.properties,
    };

IncidentCreateRequest _$IncidentCreateRequestFromJson(
        Map<String, dynamic> json) =>
    IncidentCreateRequest(
      title: json['title'] as String,
      description: json['description'] as String,
      category: (json['category'] as num).toInt(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      incidentDate: json['incident_date'] as String,
      cityName: json['city_name'] as String,
    );

Map<String, dynamic> _$IncidentCreateRequestToJson(
        IncidentCreateRequest instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'incident_date': instance.incidentDate,
      'city_name': instance.cityName,
    };

IncidentCreateResponseLocation _$IncidentCreateResponseLocationFromJson(
        Map<String, dynamic> json) =>
    IncidentCreateResponseLocation(
      type: json['type'] as String,
      coordinates: (json['coordinates'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$IncidentCreateResponseLocationToJson(
        IncidentCreateResponseLocation instance) =>
    <String, dynamic>{
      'type': instance.type,
      'coordinates': instance.coordinates,
    };

IncidentCreateResponse _$IncidentCreateResponseFromJson(
        Map<String, dynamic> json) =>
    IncidentCreateResponse(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String,
      category: (json['category'] as num).toInt(),
      incidentDate: DateTime.parse(json['incident_date'] as String),
      cityName: json['city_name'] as String,
      location: IncidentCreateResponseLocation.fromJson(
          json['location'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$IncidentCreateResponseToJson(
        IncidentCreateResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'category': instance.category,
      'incident_date': instance.incidentDate.toIso8601String(),
      'city_name': instance.cityName,
      'location': instance.location,
    };
