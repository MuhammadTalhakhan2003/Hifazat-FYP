import 'package:json_annotation/json_annotation.dart';

part 'incident.g.dart';

@JsonSerializable()
class Geometry {
  final String type;
  final List<double> coordinates;
  Geometry({required this.type, required this.coordinates});
  factory Geometry.fromJson(Map<String, dynamic> json) => _$GeometryFromJson(json);
  Map<String, dynamic> toJson() => _$GeometryToJson(this);
}

@JsonSerializable()
class IncidentProperties {
  final int id;
  final String title;
  final String? description;
  final int category;
  @JsonKey(name: 'category_name')
  final String categoryName;
  @JsonKey(name: 'incident_date')
  final DateTime incidentDate;
  @JsonKey(name: 'city_name')
  final String? cityName;
  @JsonKey(name: 'reported_by')
  final int? reportedBy;
  @JsonKey(name: 'reported_by_username')
  final String? reportedByUsername;
  final int? upvotes;
  final int? downvotes;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'current_user_vote', includeFromJson: false, includeToJson: false)
  final String? currentUserVote;

  IncidentProperties({
    required this.id, required this.title, this.description, required this.category,
    required this.categoryName, required this.incidentDate, this.cityName,
    this.reportedBy, this.reportedByUsername, this.upvotes, this.downvotes,
    this.createdAt, this.currentUserVote,
  });

  IncidentProperties copyWith({int? upvotes, int? downvotes}) {
    return IncidentProperties(
      id: id, title: title, description: description, category: category,
      categoryName: categoryName, incidentDate: incidentDate, cityName: cityName,
      reportedBy: reportedBy, reportedByUsername: reportedByUsername, createdAt: createdAt,
      upvotes: upvotes ?? this.upvotes, downvotes: downvotes ?? this.downvotes,
      currentUserVote: currentUserVote,
    );
  }

  factory IncidentProperties.fromJson(Map<String, dynamic> json) => _$IncidentPropertiesFromJson(json);
  Map<String, dynamic> toJson() => _$IncidentPropertiesToJson(this);
}

@JsonSerializable()
class Incident {
  final int id;
  final String type;
  final Geometry geometry;
  final IncidentProperties properties;

  Incident({required this.id, required this.type, required this.geometry, required this.properties});

  Incident copyWith({IncidentProperties? properties}) {
    return Incident(id: id, type: type, geometry: geometry, properties: properties ?? this.properties);
  }

  factory Incident.fromJson(Map<String, dynamic> json) {
    final propertiesJson = json['properties'] as Map<String, dynamic>;
    propertiesJson['id'] = json['id'];
    if (json.containsKey('current_user_vote')) {
      propertiesJson['current_user_vote'] = json['current_user_vote'];
    }
    return Incident(
      id: json['id'] as int,
      type: json['type'] as String,
      geometry: Geometry.fromJson(json['geometry'] as Map<String, dynamic>),
      properties: IncidentProperties.fromJson(propertiesJson),
    );
  }

  Map<String, dynamic> toJson() => _$IncidentToJson(this);
}

@JsonSerializable()
class IncidentCreateRequest {
  final String title;
  final String description;
  final int category;
  final double latitude;
  final double longitude;
  @JsonKey(name: 'incident_date')
  final String incidentDate;
  @JsonKey(name: 'city_name')
  final String cityName;

  IncidentCreateRequest({
    required this.title, required this.description, required this.category,
    required this.latitude, required this.longitude, required this.incidentDate,
    required this.cityName,
  });

  factory IncidentCreateRequest.fromJson(Map<String, dynamic> json) => _$IncidentCreateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$IncidentCreateRequestToJson(this);
}

// --- FIX: Add these classes to handle the specific POST response ---

@JsonSerializable()
class IncidentCreateResponseLocation {
  final String type;
  final List<double> coordinates;
  IncidentCreateResponseLocation({required this.type, required this.coordinates});
  factory IncidentCreateResponseLocation.fromJson(Map<String, dynamic> json) => _$IncidentCreateResponseLocationFromJson(json);
  Map<String, dynamic> toJson() => _$IncidentCreateResponseLocationToJson(this);
}

@JsonSerializable()
class IncidentCreateResponse {
  final int id;
  final String title;
  final String description;
  final int category;
  @JsonKey(name: 'incident_date')
  final DateTime incidentDate;
  @JsonKey(name: 'city_name')
  final String cityName;
  final IncidentCreateResponseLocation location;

  IncidentCreateResponse({
    required this.id, required this.title, required this.description,
    required this.category, required this.incidentDate, required this.cityName,
    required this.location,
  });

  factory IncidentCreateResponse.fromJson(Map<String, dynamic> json) => _$IncidentCreateResponseFromJson(json);
  Map<String, dynamic> toJson() => _$IncidentCreateResponseToJson(this);

  // Helper method to convert this flat response into the standard GeoJSON Incident model
  Incident toStandardIncident() {
    return Incident(
      id: id,
      type: 'Feature',
      geometry: Geometry(
        type: location.type,
        coordinates: location.coordinates,
      ),
      properties: IncidentProperties(
        id: id,
        title: title,
        description: description,
        category: category,
        incidentDate: incidentDate,
        cityName: cityName,
        // Provide sensible defaults for fields not present in the POST response
        categoryName: 'Unknown',
        reportedBy: 0,
        reportedByUsername: 'You',
        upvotes: 0,
        downvotes: 0,
        createdAt: DateTime.now(),
      ),
    );
  }
}