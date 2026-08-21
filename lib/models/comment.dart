import 'package:hive/hive.dart';

//part 'comment.g.dart';

@HiveType(typeId: 3)
class Comment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String text;

  @HiveField(2)
  final String authorName;

  @HiveField(3)
  final String authorProfileUrl;

  @HiveField(4)
  final int likeCount;

  @HiveField(5)
  final DateTime publishedAt;

  @HiveField(6)
  final bool isReply;

  @HiveField(7)
  final String? parentId;

  @HiveField(8)
  final int replyCount;

  Comment({
    required this.id,
    required this.text,
    required this.authorName,
    required this.authorProfileUrl,
    required this.likeCount,
    required this.publishedAt,
    this.isReply = false,
    this.parentId,
    this.replyCount = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    return Comment(
      id: json['id'],
      text: snippet['textDisplay'],
      authorName: snippet['authorDisplayName'],
      authorProfileUrl: snippet['authorProfileImageUrl'],
      likeCount: int.parse(snippet['likeCount']),
      publishedAt: DateTime.parse(snippet['publishedAt']),
      isReply: snippet['parentId'] != null,
      parentId: snippet['parentId'],
      replyCount: json['replies']?['totalReplyCount'] ?? 0,
    );
  }
}
