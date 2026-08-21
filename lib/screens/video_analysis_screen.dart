import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/youtube_service.dart';
import '../models/video.dart';
import '../constants/app_config.dart';
import '../widgets/video_card.dart';
import '../widgets/thumbnail_menu.dart';

class VideoAnalysisScreen extends StatefulWidget {
  final String videoUrl;

  const VideoAnalysisScreen({super.key, required this.videoUrl});

  @override
  State<VideoAnalysisScreen> createState() => _VideoAnalysisScreenState();
}

Future<void> _launchYouTubeVideo(String videoId) async {
  final url = Uri.parse('https://youtube.com/watch?v=$videoId');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

class _VideoAnalysisScreenState extends State<VideoAnalysisScreen>
    with SingleTickerProviderStateMixin {
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  late TabController _tabController;
  Video? _video;
  List<String> _tags = [];
  List<String> _suggestedKeywords = [];
  List<Video> _competitors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadVideoData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVideoData() async {
    try {
      setState(() => _isLoading = true);

      // Extract video ID from URL
      String videoId = widget.videoUrl.trim();

      // Check various YouTube URL formats
      Uri? uri;
      try {
        uri = Uri.parse(videoId);
      } catch (e) {
        throw Exception('Invalid URL format');
      }

      if (uri.host.contains('youtube.com')) {
        if (uri.queryParameters.containsKey('v')) {
          // Regular YouTube URL: youtube.com/watch?v=ID
          videoId = uri.queryParameters['v']!;
        } else if (uri.path.contains('/shorts/')) {
          // YouTube Shorts URL: youtube.com/shorts/ID
          videoId = uri.pathSegments[uri.pathSegments.indexOf('shorts') + 1];
        } else {
          throw Exception('Could not find video ID in YouTube URL');
        }
      } else if (uri.host.contains('youtu.be')) {
        // Short YouTube URL: youtu.be/ID
        videoId = uri.pathSegments.first;
      } else {
        throw Exception('Not a valid YouTube URL');
      }

      if (videoId.isEmpty) {
        throw Exception('Could not extract video ID from URL');
      }

      // First get the video details
      try {
        final video = await _youtubeService.getVideoDetails(videoId);

        // Then load tags, keywords and competitors in parallel
        final results = await Future.wait([
          _youtubeService.suggestTags(video.title),
          _youtubeService.getDetailedKeywordSuggestions(videoId),
          _youtubeService.findCompetitors(video),
        ]);

        setState(() {
          _video = video;
          _tags = results[0] as List<String>;
          _suggestedKeywords =
              (results[1] as Map<String, List<String>>).values
                  .expand((x) => x)
                  .toList();
          _competitors = results[2] as List<Video>;
          _isLoading = false;
        });
      } catch (e) {
        throw Exception('Video not found or is not accessible');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Analysis'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tags'),
            Tab(text: 'Keywords'),
            Tab(text: 'Competitors'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Error: $_error',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTagsTab(),
                _buildKeywordsTab(),
                _buildCompetitorsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (_video == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _launchYouTubeVideo(_video!.id),
                    child: Stack(
                      children: [
                        Image.network(_video!.thumbnailUrl, fit: BoxFit.cover),
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              size: 40,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: ThumbnailMenu(
                  videoId: _video!.id,
                  videoTitle: _video!.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(_video!.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _video!.channelTitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatRow('Views', _formatNumber(_video!.viewCount)),
                  const Divider(),
                  _buildStatRow('Likes', _formatNumber(_video!.likeCount)),
                  const Divider(),
                  _buildStatRow(
                    'Comments',
                    _formatNumber(_video!.commentCount),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Description', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_video!.description),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Video Tags (${_tags.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                              ),
                              onDeleted: () {
                                Clipboard.setData(ClipboardData(text: tag));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied "$tag" to clipboard'),
                                  ),
                                );
                              },
                              deleteIcon: const Icon(Icons.copy),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested Keywords',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _suggestedKeywords
                          .map(
                            (keyword) => Chip(
                              label: Text(keyword),
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                              labelStyle: TextStyle(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                              ),
                              onDeleted: () {
                                Clipboard.setData(ClipboardData(text: keyword));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Copied "$keyword" to clipboard',
                                    ),
                                  ),
                                );
                              },
                              deleteIcon: const Icon(Icons.copy),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompetitorsTab() {
    if (_competitors.isEmpty || _video == null) {
      return const Center(
        child: Text('No competitors found', style: TextStyle(fontSize: 16)),
      );
    }
    final avgCompetitorViews =
        _competitors.fold<int>(0, (sum, video) => sum + video.viewCount) ~/
        _competitors.length;
    final avgCompetitorLikes =
        _competitors.fold<int>(0, (sum, video) => sum + video.likeCount) ~/
        _competitors.length;
    final avgCompetitorComments =
        _competitors.fold<int>(0, (sum, video) => sum + video.commentCount) ~/
        _competitors.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance Comparison',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _buildComparisonRow(
                  'Views',
                  _video!.viewCount,
                  avgCompetitorViews,
                ),
                const SizedBox(height: 8),
                _buildComparisonRow(
                  'Likes',
                  _video!.likeCount,
                  avgCompetitorLikes,
                ),
                const SizedBox(height: 8),
                _buildComparisonRow(
                  'Comments',
                  _video!.commentCount,
                  avgCompetitorComments,
                ),
                const SizedBox(height: 8),
                _buildComparisonRow(
                  'Engagement Rate',
                  (_video!.likeCount / _video!.viewCount * 100).round(),
                  ((avgCompetitorLikes / avgCompetitorViews) * 100).round(),
                  isPercentage: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Similar Videos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._competitors.map(
          (video) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: VideoCard(
              video: video,
              onTap: () => _launchYouTubeVideo(video.id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(
    String label,
    int value,
    int avgValue, {
    bool isPercentage = false,
  }) {
    final performance = value > avgValue ? 'Above' : 'Below';
    final formattedValue = isPercentage ? '$value%' : _formatNumber(value);
    final formattedAvg = isPercentage ? '$avgValue%' : _formatNumber(avgValue);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedValue,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: value > avgValue ? Colors.green : Colors.red,
                    ),
                    children: [
                      TextSpan(text: '$performance avg '),
                      TextSpan(
                        text: '($formattedAvg)',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
