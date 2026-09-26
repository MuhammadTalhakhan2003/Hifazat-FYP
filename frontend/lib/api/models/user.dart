// User profile models
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class UserProfile {
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  // Granted by moderators; shown as the "Verified" badge.
  @JsonKey(name: 'is_trusted_reporter')
  final bool isTrustedReporter;

  UserProfile({this.avatarUrl, this.isTrustedReporter = false});

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

@JsonSerializable(explicitToJson: true)
class User {
  final int id;
  final String username;
  final String email;
  @JsonKey(name: 'first_name')
  final String? firstName;
  @JsonKey(name: 'last_name')
  final String? lastName;
  @JsonKey(name: 'is_staff')
  final bool isStaff;
  final UserProfile? profile;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.isStaff = false,
    this.profile,
  });

  bool get isVerified => profile?.isTrustedReporter ?? false;

  String get displayName {
    final fullName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return fullName.isEmpty ? username : fullName;
  }

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}


@JsonSerializable()
class Reputation {
  @JsonKey(name: 'user_id')
  final int userId;
  final String username;
  @JsonKey(name: 'reputation_score')
  final int reputationScore;

  Reputation({
    required this.userId, 
    required this.username, 
    required this.reputationScore,
  });

  factory Reputation.fromJson(Map<String, dynamic> json) => _$ReputationFromJson(json);
  Map<String, dynamic> toJson() => _$ReputationToJson(this);
}