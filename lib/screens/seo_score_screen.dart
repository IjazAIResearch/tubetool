import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubegrow/constants/app_config.dart';
import 'package:tubegrow/services/youtube_service.dart';
import 'package:tubegrow/services/youtube_url_service.dart';
import '../services/review_service.dart';
import 'dart:math';

class SeoScoreScreen extends StatefulWidget {
  const SeoScoreScreen({super.key});

  @override
  State<SeoScoreScreen> createState() => _SeoScoreScreenState();
}

class _SeoScoreScreenState extends State<SeoScoreScreen>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  bool _isLoading = false;
  Map<String, dynamic>? _scoreData;
  AnimationController? _animController;
  Animation<double>? _scoreAnimation;

  @override
  void dispose() {
    _urlController.dispose();
    _animController?.dispose();
    super.dispose();
  }

  Future<void> _analyzeVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final videoId = YouTubeUrlService.extractVideoId(url);
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid YouTube video URL')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _scoreData = null;
    });

    try {
      final video = await _youtubeService.getVideoDetails(videoId);

      // Calculate scores
      final titleScore = _calculateTitleScore(video.title);
      final descriptionScore = _calculateDescriptionScore(video.description);
      final tagScore = _calculateTagScore(video.tags);
      final engagementScore = _calculateEngagementScore(
        video.viewCount,
        video.likeCount,
        video.commentCount,
      );

      final overallScore =
          ((titleScore + descriptionScore + tagScore + engagementScore) / 4)
              .round();

      setState(() {
        _scoreData = {
          'overall': overallScore,
          'title': {
            'score': titleScore,
            'value': video.title,
            'tips': _getTitleTips(video.title),
          },
          'description': {
            'score': descriptionScore,
            'value': video.description,
            'tips': _getDescriptionTips(video.description),
          },
          'tags': {
            'score': tagScore,
            'count': video.tags.length,
            'tips': _getTagTips(video.tags),
          },
          'engagement': {
            'score': engagementScore,
            'views': video.viewCount,
            'likes': video.likeCount,
            'comments': video.commentCount,
            'tips': _getEngagementTips(video.viewCount, video.likeCount),
          },
        };
        _isLoading = false;
      });

      // Animate the score
      _animController?.dispose();
      _animController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );
      _scoreAnimation = Tween<double>(begin: 0, end: overallScore.toDouble())
          .animate(CurvedAnimation(
        parent: _animController!,
        curve: Curves.easeOutCubic,
      ));
      _animController!.forward();

      // Record feature use and try to show review at the success moment
      await ReviewService.instance.recordFeatureUse('seo_score');
      ReviewService.instance.tryShowReview();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  int _calculateTitleScore(String title) {
    int score = 0;
    // Length: 50-60 is ideal
    if (title.length >= 40 && title.length <= 70) {
      score += 30;
    } else if (title.length >= 20 && title.length <= 100) {
      score += 15;
    } else {
      score += 5;
    }
    // Contains numbers (higher CTR)
    if (RegExp(r'\d').hasMatch(title)) score += 15;
    // Contains power words
    final powerWords = [
      'best', 'top', 'how', 'ultimate', 'guide', 'tutorial', 'review',
      'tips', 'secrets', 'amazing', 'free', 'new', 'easy', 'simple',
      'must', 'watch', 'complete', 'full', 'epic', 'learn',
    ];
    if (powerWords.any((w) => title.toLowerCase().contains(w))) score += 20;
    // Contains emoji
    if (RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true).hasMatch(title)) {
      score += 10;
    }
    // Capitalization check (at least some caps)
    if (title != title.toLowerCase()) score += 10;
    // Not all caps
    if (title != title.toUpperCase()) score += 15;

    return min(score, 100);
  }

  int _calculateDescriptionScore(String desc) {
    int score = 0;
    final wordCount = desc.split(RegExp(r'\s+')).length;

    // Length: 200+ words ideal
    if (wordCount >= 200) {
      score += 30;
    } else if (wordCount >= 100) {
      score += 20;
    } else if (wordCount >= 50) {
      score += 10;
    }
    // Contains links
    if (desc.contains('http')) score += 15;
    // Contains hashtags
    if (desc.contains('#')) score += 10;
    // Contains timestamps
    if (RegExp(r'\d{1,2}:\d{2}').hasMatch(desc)) score += 15;
    // Contains social media links
    if (desc.toLowerCase().contains('instagram') ||
        desc.toLowerCase().contains('twitter') ||
        desc.toLowerCase().contains('facebook')) {
      score += 10;
    }
    // Contains keywords/call to action
    final cta = ['subscribe', 'like', 'comment', 'share', 'follow'];
    if (cta.any((w) => desc.toLowerCase().contains(w))) score += 20;

    return min(score, 100);
  }

  int _calculateTagScore(List<String> tags) {
    int score = 0;
    // Number of tags
    if (tags.length >= 15) {
      score += 40;
    } else if (tags.length >= 10) {
      score += 30;
    } else if (tags.length >= 5) {
      score += 20;
    } else if (tags.isNotEmpty) {
      score += 10;
    }
    // Mix of short and long tags
    final shortTags = tags.where((t) => t.split(' ').length <= 2).length;
    final longTags = tags.where((t) => t.split(' ').length >= 3).length;
    if (shortTags > 0 && longTags > 0) score += 20;
    // Tag variety
    if (tags.length > 5) score += 20;
    // Not too many tags
    if (tags.length <= 30) score += 20;

    return min(score, 100);
  }

  int _calculateEngagementScore(int views, int likes, int comments) {
    int score = 0;
    if (views == 0) return 0;

    final likeRatio = likes / views;
    final commentRatio = comments / views;

    // Like ratio
    if (likeRatio >= 0.05) {
      score += 40;
    } else if (likeRatio >= 0.03) {
      score += 30;
    } else if (likeRatio >= 0.01) {
      score += 20;
    } else {
      score += 10;
    }

    // Comment ratio
    if (commentRatio >= 0.01) {
      score += 30;
    } else if (commentRatio >= 0.005) {
      score += 20;
    } else if (commentRatio >= 0.001) {
      score += 10;
    }

    // View milestone
    if (views >= 1000000) {
      score += 30;
    } else if (views >= 100000) {
      score += 25;
    } else if (views >= 10000) {
      score += 20;
    } else if (views >= 1000) {
      score += 15;
    } else {
      score += 5;
    }

    return min(score, 100);
  }

  List<String> _getTitleTips(String title) {
    final tips = <String>[];
    if (title.length < 40) tips.add('Make your title longer (40-70 chars ideal)');
    if (title.length > 70) tips.add('Shorten your title (40-70 chars ideal)');
    if (!RegExp(r'\d').hasMatch(title)) tips.add('Add numbers for higher CTR');
    if (title == title.toUpperCase()) tips.add('Avoid ALL CAPS titles');
    if (tips.isEmpty) tips.add('✅ Great title optimization!');
    return tips;
  }

  List<String> _getDescriptionTips(String desc) {
    final tips = <String>[];
    final wordCount = desc.split(RegExp(r'\s+')).length;
    if (wordCount < 100) tips.add('Add more description (200+ words recommended)');
    if (!desc.contains('#')) tips.add('Add relevant hashtags');
    if (!RegExp(r'\d{1,2}:\d{2}').hasMatch(desc)) tips.add('Add timestamps for chapters');
    if (!desc.contains('http')) tips.add('Add relevant links');
    if (tips.isEmpty) tips.add('✅ Excellent description!');
    return tips;
  }

  List<String> _getTagTips(List<String> tags) {
    final tips = <String>[];
    if (tags.isEmpty) tips.add('Add tags! They help YouTube understand your content');
    if (tags.length < 10) tips.add('Add more tags (15+ recommended)');
    if (tags.length > 30) tips.add('Too many tags can dilute relevance');
    final shortOnly = tags.every((t) => t.split(' ').length <= 1);
    if (shortOnly) tips.add('Mix short and long-tail keyword tags');
    if (tips.isEmpty) tips.add('✅ Great tag strategy!');
    return tips;
  }

  List<String> _getEngagementTips(int views, int likes) {
    final tips = <String>[];
    if (views > 0) {
      final ratio = likes / views;
      if (ratio < 0.03) tips.add('Encourage viewers to like (ask in video)');
    }
    tips.add('Reply to comments to boost engagement');
    tips.add('Pin a comment with a call-to-action');
    return tips;
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Needs Work';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('SEO Score')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                  // URL Input
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'Paste YouTube video URL...',
                      prefixIcon: Icon(Icons.link, color: colorScheme.primary),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search, color: colorScheme.primary),
                        onPressed: _analyzeVideo,
                      ),
                    ),
                    onSubmitted: (_) => _analyzeVideo(),
                  ),
                  const SizedBox(height: 24),

                  if (_isLoading)
                    const Center(
                      child: Column(
                        children: [
                          SizedBox(height: 40),
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Analyzing video SEO...'),
                        ],
                      ),
                    ),

                  if (_scoreData != null) ...[
                    // Overall Score
                    Center(
                      child: AnimatedBuilder(
                        animation: _scoreAnimation!,
                        builder: (context, _) {
                          final score = _scoreAnimation!.value.round();
                          return Column(
                            children: [
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      height: 140,
                                      child: CircularProgressIndicator(
                                        value: score / 100,
                                        strokeWidth: 12,
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        color: _getScoreColor(score),
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$score',
                                          style: TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            color: _getScoreColor(score),
                                          ),
                                        ),
                                        Text(
                                          '/100',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: colorScheme.onSurface
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getScoreColor(
                                          _scoreData!['overall'])
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getScoreLabel(_scoreData!['overall']),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getScoreColor(
                                        _scoreData!['overall']),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Breakdown cards
                    _buildScoreCard(
                      'Title',
                      Icons.title,
                      _scoreData!['title']['score'],
                      _scoreData!['title']['tips'],
                      subtitle: _scoreData!['title']['value'],
                    ),
                    _buildScoreCard(
                      'Description',
                      Icons.description,
                      _scoreData!['description']['score'],
                      _scoreData!['description']['tips'],
                    ),
                    _buildScoreCard(
                      'Tags',
                      Icons.local_offer,
                      _scoreData!['tags']['score'],
                      _scoreData!['tags']['tips'],
                      subtitle: '${_scoreData!['tags']['count']} tags found',
                    ),
                    _buildScoreCard(
                      'Engagement',
                      Icons.thumb_up,
                      _scoreData!['engagement']['score'],
                      _scoreData!['engagement']['tips'],
                      subtitle:
                          '${_formatNumber(_scoreData!['engagement']['views'])} views • '
                          '${_formatNumber(_scoreData!['engagement']['likes'])} likes',
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildScoreCard(
    String title,
    IconData icon,
    int score,
    List<String> tips, {
    String? subtitle,
  }) {
    final color = _getScoreColor(score);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$score/100',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      tip.startsWith('✅') ? Icons.check_circle : Icons.info,
                      size: 16,
                      color: tip.startsWith('✅') ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }
}
