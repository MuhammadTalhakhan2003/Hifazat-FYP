// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vote_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VoteResponse _$VoteResponseFromJson(Map<String, dynamic> json) => VoteResponse(
      upvotes: (json['upvotes'] as num).toInt(),
      downvotes: (json['downvotes'] as num).toInt(),
      currentUserVote: json['current_user_vote'] as String?,
    );

Map<String, dynamic> _$VoteResponseToJson(VoteResponse instance) =>
    <String, dynamic>{
      'upvotes': instance.upvotes,
      'downvotes': instance.downvotes,
      'current_user_vote': instance.currentUserVote,
    };
