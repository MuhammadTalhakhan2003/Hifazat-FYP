import 'package:json_annotation/json_annotation.dart';

part 'vote_response.g.dart';

@JsonSerializable()
class VoteResponse {
  final int upvotes;
  final int downvotes;
  @JsonKey(name: 'current_user_vote')
  final String? currentUserVote; // Can be 'up', 'down', or null

  VoteResponse({
    required this.upvotes,
    required this.downvotes,
    this.currentUserVote,
  });

  factory VoteResponse.fromJson(Map<String, dynamic> json) => _$VoteResponseFromJson(json);
  Map<String, dynamic> toJson() => _$VoteResponseToJson(this);
}