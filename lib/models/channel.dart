import 'package:hive/hive.dart';

//part 'channel.g.dart';

@HiveType(typeId: 2)
class Channel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String thumbnailUrl;

  @HiveField(4)
  final String bannerUrl;

  @HiveField(5)
  final int subscriberCount;

  @HiveField(6)
  final int videoCount;

  @HiveField(7)
  final int viewCount;

  @HiveField(8)
  final String country;
  @HiveField(9)
  final DateTime joinedDate;

  @HiveField(10)
  final String? customUrl;

  Channel({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.bannerUrl,
    required this.subscriberCount,
    required this.videoCount,
    required this.viewCount,
    required this.country,
    required this.joinedDate,
    this.customUrl,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    final statistics = json['statistics'];
    final thumbnails = snippet['thumbnails'];
    return Channel(
      id: json['id'],
      title: snippet['title'],
      description: snippet['description'],
      thumbnailUrl:
          thumbnails['high']?['url'] ?? thumbnails['default']?['url'] ?? '',
      bannerUrl: json['brandingSettings']?['image']?['bannerExternalUrl'] ?? '',
      subscriberCount: int.tryParse(statistics['subscriberCount'] ?? '0') ?? 0,
      videoCount: int.tryParse(statistics['videoCount'] ?? '0') ?? 0,
      viewCount: int.tryParse(statistics['viewCount'] ?? '0') ?? 0,
      country: snippet['country'] ?? 'Unknown',
      joinedDate: DateTime.tryParse(snippet['publishedAt']) ?? DateTime.now(),
      customUrl: snippet['customUrl'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'snippet': {
        'title': title,
        'customUrl': customUrl,
        'description': description,
        'thumbnails': {
          'high': {'url': thumbnailUrl},
        },
        'country': country,
        'publishedAt': joinedDate.toIso8601String(),
      },
      'statistics': {
        'subscriberCount': subscriberCount.toString(),
        'videoCount': videoCount.toString(),
        'viewCount': viewCount.toString(),
      },
      'brandingSettings': {
        'image': {'bannerExternalUrl': bannerUrl},
      },
    };
  }

  String get url {
    // If we have a custom handle/username, use that
    if (customUrl?.isNotEmpty == true) {
      return 'https://youtube.com/$customUrl';
    }
    // Fall back to channel ID format
    return 'https://youtube.com/channel/$id';
  }

  // Monetization status based on YouTube Partner Program requirements
  bool get isMonetized =>
      subscriberCount >= 1000 &&
      viewCount >= 4000 * 60; // 4000 hours = 240,000 minutes

  // Estimated monthly earnings based on typical YouTube CPM rates
  double estimateMonthlyEarnings({double cpm = 2.0}) {
    if (!isMonetized) return 0.0;
    // Assume 60% of views are monetized
    final monetizedViews = (viewCount * 0.6) / 12; // Monthly views
    return (monetizedViews / 1000) * cpm;
  }

  // Estimated yearly earnings
  double estimateYearlyEarnings({double cpm = 2.0}) {
    return estimateMonthlyEarnings(cpm: cpm) * 12;
  }

  // Channel age in days
  int get channelAge => DateTime.now().difference(joinedDate).inDays;

  // Average views per video
  double get averageViewsPerVideo =>
      videoCount > 0 ? viewCount / videoCount : 0;

  // Engagement rate (views to subscriber ratio)
  double get engagementRate =>
      subscriberCount > 0 ? (viewCount / subscriberCount) : 0;

  // Growth rate (subscribers per day)
  double get dailyGrowthRate =>
      channelAge > 0 ? subscriberCount / channelAge : 0;

  // Return formatted subscriber count (e.g., 1.2M, 456K)
  String get formattedSubscriberCount {
    if (subscriberCount >= 1000000) {
      return '${(subscriberCount / 1000000).toStringAsFixed(1)}M';
    } else if (subscriberCount >= 1000) {
      return '${(subscriberCount / 1000).toStringAsFixed(1)}K';
    }
    return subscriberCount.toString();
  }

  // Return formatted view count
  String get formattedViewCount {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    }
    return viewCount.toString();
  }
}
