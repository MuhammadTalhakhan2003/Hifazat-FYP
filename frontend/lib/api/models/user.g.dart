// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
      avatarUrl: json['avatar_url'] as String?,
      isTrustedReporter: json['is_trusted_reporter'] as bool? ?? false,
    );

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'avatar_url': instance.avatarUrl,
      'is_trusted_reporter': instance.isTrustedReporter,
    };

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      isStaff: json['is_staff'] as bool? ?? false,
      profile: json['profile'] == null
          ? null
          : UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'is_staff': instance.isStaff,
      'profile': instance.profile?.toJson(),
    };

Reputation _$ReputationFromJson(Map<String, dynamic> json) => Reputation(
      userId: (json['user_id'] as num).toInt(),
      username: json['username'] as String,
      reputationScore: (json['reputation_score'] as num).toInt(),
    );

Map<String, dynamic> _$ReputationToJson(Reputation instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'username': instance.username,
      'reputation_score': instance.reputationScore,
    };
