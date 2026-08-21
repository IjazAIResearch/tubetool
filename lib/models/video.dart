class Video {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final List<String> tags;
  final String channelId;
  final String channelTitle;
  final DateTime publishedAt;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final Duration duration;

  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.tags,
    required this.channelId,
    required this.channelTitle,
    required this.publishedAt,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.duration,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    String? durationStr = json['contentDetails']?['duration'];
    Duration videoDuration = Duration.zero;

    if (durationStr != null) {
      // Parse ISO 8601 duration format
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(durationStr);
      if (match != null) {
        final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
        final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
        videoDuration = Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
        );
      }
    }

    return Video(
      id: json['id'],
      title: json['snippet']['title'],
      description: json['snippet']['description'],
      thumbnailUrl: json['snippet']['thumbnails']['high']['url'],
      tags: List<String>.from(json['snippet']['tags'] ?? []),
      channelId: json['snippet']['channelId'],
      channelTitle: json['snippet']['channelTitle'],
      publishedAt: DateTime.parse(json['snippet']['publishedAt']),
      viewCount: int.parse(json['statistics']['viewCount'] ?? '0'),
      likeCount: int.parse(json['statistics']['likeCount'] ?? '0'),
      commentCount: int.parse(json['statistics']['commentCount'] ?? '0'),
      duration: videoDuration,
    );
  }

  Map<String, dynamic> toJson() {
    String durationToIso8601() {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      return 'PT${hours > 0 ? '${hours}H' : ''}${minutes > 0 ? '${minutes}M' : ''}${seconds > 0 ? '${seconds}S' : ''}';
    }

    return {
      'id': id,
      'snippet': {
        'title': title,
        'description': description,
        'thumbnails': {
          'high': {'url': thumbnailUrl},
        },
        'tags': tags,
        'channelId': channelId,
        'channelTitle': channelTitle,
        'publishedAt': publishedAt.toIso8601String(),
      },
      'statistics': {
        'viewCount': viewCount.toString(),
        'likeCount': likeCount.toString(),
        'commentCount': commentCount.toString(),
      },
      'contentDetails': {'duration': durationToIso8601()},
    };
  }

  String get url => 'https://youtube.com/watch?v=$id';
}
