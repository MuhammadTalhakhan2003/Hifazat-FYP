// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Comment _$CommentFromJson(Map<String, dynamic> json) => Comment(
      id: (json['id'] as num).toInt(),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      parentComment: (json['parent_comment'] as num?)?.toInt(),
      replies: (json['replies'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$CommentToJson(Comment instance) => <String, dynamic>{
      'id': instance.id,
      'user': instance.user.toJson(),
      'content': instance.content,
      'created_at': instance.createdAt.toIso8601String(),
      'parent_comment': instance.parentComment,
      'replies': instance.replies.map((e) => e.toJson()).toList(),
    };

CommentCreateRequest _$CommentCreateRequestFromJson(
        Map<String, dynamic> json) =>
    CommentCreateRequest(
      content: json['content'] as String,
      parentComment: (json['parent_comment'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CommentCreateRequestToJson(
        CommentCreateRequest instance) =>
    <String, dynamic>{
      'content': instance.content,
      'parent_comment': instance.parentComment,
    };
