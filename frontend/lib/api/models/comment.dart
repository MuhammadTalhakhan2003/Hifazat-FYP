import 'package:hifazat_app/api/models/user.dart'; // Import the User model
import 'package:json_annotation/json_annotation.dart';

part 'comment.g.dart';

@JsonSerializable(explicitToJson: true) // Add explicitToJson here too
class Comment {
  final int id;
  // FIX: Change the type from int to User
  final User user;
  
  // We can now get the username directly from the nested user object
  // So, this field is redundant, but we'll keep it for now to avoid breaking other parts
  @JsonKey(name: 'user_username', readValue: _readUsername, includeFromJson: false, includeToJson: false)
  final String userUsername;
  
  final String content;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'parent_comment')
  final int? parentComment;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.user, // FIX: Update constructor
    required this.content,
    required this.createdAt,
    this.parentComment,
    this.replies = const [],
  }) : userUsername = user.username; // Initialize userUsername from the User object

  factory Comment.fromJson(Map<String, dynamic> json) => _$CommentFromJson(json);
  Map<String, dynamic> toJson() => _$CommentToJson(this);
}

// Helper function for the now-redundant user_username field
Object? _readUsername(Map json, String key) {
  return (json['user'] as Map<String, dynamic>)['username'];
}


@JsonSerializable()
class CommentCreateRequest {
  final String content;
  @JsonKey(name: 'parent_comment')
  final int? parentComment;

  CommentCreateRequest({required this.content, this.parentComment});

  factory CommentCreateRequest.fromJson(Map<String, dynamic> json) => _$CommentCreateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CommentCreateRequestToJson(this);
}