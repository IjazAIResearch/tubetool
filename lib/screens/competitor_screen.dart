import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubegrow/services/youtube_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_config.dart';
import '../models/channel.dart';
import '../models/video.dart';
import '../services/youtube_url_service.dart';
import '../widgets/video_card.dart';

class CompetitorScreen extends StatefulWidget {
  const CompetitorScreen({super.key});

  @override
  State<CompetitorScreen> createState() => _CompetitorScreenState();
}

class _CompetitorScreenState extends State<CompetitorScreen> {
  final _searchController = TextEditingController();
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  Channel? _channel;
  Video? _videoCompetitor;
  List<Video> _videos = [];
  bool _isLoading = false;
  String? _error;
  bool _isAnalyzing = false;
  Map<String, double> _videoStats = {
    'avgViews': 0,
    'avgLikes': 0,
    'avgComments': 0,
  };
  List<Video> competitors = [];
  List<Channel> similarChannels = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchChannel() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _channel = null;
      _videoCompetitor = null;
      _videos.clear();
      _videoStats = {'avgViews': 0, 'avgLikes': 0, 'avgComments': 0};
    });

    try {
      final input = _searchController.text.trim();
      String? channelId;

      // First try to extract video ID
      final videoId = YouTubeUrlService.extractVideoId(input);

      if (videoId != null) {
        try {
          final videoData = await _youtubeService.getVideoDetails(videoId);
          setState(() {
            _videoCompetitor = videoData;
          });
          channelId = videoData.channelId;
        } catch (e) {
          throw Exception(
            'Could not load video details. The video might be private or deleted.',
          );
        }
      } else {
        // Try to extract channel ID or username
        channelId = YouTubeUrlService.extractChannelId(input);
        final username = YouTubeUrlService.extractUsername(input);

        if (channelId == null && username != null) {
          try {
            channelId = await _youtubeService.getChannelId(username);
          } catch (e) {
            throw Exception(
              'Could not find channel. The channel might be private or deleted.',
            );
          }
        } else if (channelId == null) {
          try {
            // Try searching for the channel
            channelId = await _youtubeService.getChannelId(input);
          } catch (e) {
            throw Exception('''Could not find channel. Please try:
• A YouTube channel URL (youtube.com/@username)
• A channel's custom URL (youtube.com/c/channelname)
• A video URL from the channel (youtube.com/watch?v=ID)
• A Shorts URL (youtube.com/shorts/ID)
• A short video URL (youtu.be/ID)
• A channel name or search term''');
          }
        }
      }

      // Get channel details and videos
      try {
        final channelData = await _youtubeService.getChannelDetails(channelId);
        final videos = await _youtubeService.getChannelVideos(channelId);

        setState(() {
          _channel = Channel.fromJson(channelData);
          _videos = videos;
          _isLoading = false;
        });

        _analyzeChannel();
      } catch (e) {
        throw Exception(
          'Could not load channel data. The channel might be private or deleted.',
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<Video>> _findVideoCompetitors(Video video) async {
    try {
      return await _youtubeService.findCompetitors(video);
    } catch (e) {
      debugPrint('Failed to find video competitors: $e');
      return [];
    }
  }

  Future<List<Channel>> _findSimilarChannels(String title) async {
    try {
      final channels = await _youtubeService.searchChannels(title);
      // Remove the current channel from results
      if (_channel != null) {
        channels.removeWhere((c) => c.id == _channel!.id);
      }
      return channels;
    } catch (e) {
      debugPrint('Failed to find similar channels: $e');
      return [];
    }
  }

  Future<void> _analyzeChannel() async {
    setState(() => _isAnalyzing = true);

    try {
      // Start competitor search
      if (_videoCompetitor != null) {
        final videoCompetitors = await _findVideoCompetitors(_videoCompetitor!);
        setState(() {
          competitors = videoCompetitors;
        });
      }

      final foundSimilarChannels = await _findSimilarChannels(_channel!.title);
      setState(() {
        similarChannels = foundSimilarChannels;
      });

      // Calculate video statistics
      if (_videos.isNotEmpty) {
        final totalViews = _videos.fold<int>(
          0,
          (sum, video) => sum + video.viewCount,
        );
        final totalLikes = _videos.fold<int>(
          0,
          (sum, video) => sum + video.likeCount,
        );
        final totalComments = _videos.fold<int>(
          0,
          (sum, video) => sum + video.commentCount,
        );

        setState(() {
          _videoStats = {
            'avgViews': totalViews / _videos.length,
            'avgLikes': totalLikes / _videos.length,
            'avgComments': totalComments / _videos.length,
          };
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      debugPrint('Error analyzing channel: $e');
      setState(() => _isAnalyzing = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  List<Widget> _buildCompetitorList(List<Video> competitors) {
    return competitors.map((video) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: VideoCard(
          video: video,
          onTap: () => _launchUrl(video.url),
        ),
      ),
    )).toList();
  }

  List<Widget> _buildChannelList(List<Channel> channels) {
    return channels.map((channel) => Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(channel.thumbnailUrl),
        ),
        title: Text(channel.title),
        subtitle: Text(
          '${channel.subscriberCount} subscribers • ${channel.videoCount} videos',
        ),
        onTap: () => _launchUrl(channel.url),
      ),
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Competitor Analysis')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Enter channel URL or username',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchChannel,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _searchChannel(),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _searchChannel,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_channel != null)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Channel Info Card
                            Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    _channel!.thumbnailUrl,
                                  ),
                                ),
                                title: Text(_channel!.title),
                                subtitle: Text(
                                  '${_channel!.subscriberCount} subscribers • ${_channel!.videoCount} videos',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_videoCompetitor != null) ...[
                              Card(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.15),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Video Being Analyzed',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _videoCompetitor!.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Views: ${_videoCompetitor!.viewCount}',
                                      ),
                                      Text(
                                        'Likes: ${_videoCompetitor!.likeCount}',
                                      ),
                                      Text(
                                        'Comments: ${_videoCompetitor!.commentCount}',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Video Statistics Card
                            if (!_isAnalyzing) ...[
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Average Video Performance',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildStatRow(
                                        'Views',
                                        _videoStats['avgViews']!
                                            .toInt()
                                            .toString(),
                                      ),
                                      _buildStatRow(
                                        'Likes',
                                        _videoStats['avgLikes']!
                                            .toInt()
                                            .toString(),
                                      ),
                                      _buildStatRow(
                                        'Comments',
                                        _videoStats['avgComments']!
                                            .toInt()
                                            .toString(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Competitors Section
                              if (_videoCompetitor != null &&
                                  competitors.isNotEmpty) ...[
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Similar Videos',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 16),
                                        ..._buildCompetitorList(
                                          competitors,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else if (_videoCompetitor != null &&
                                  competitors.isEmpty) ...[
                                const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Text(
                                        'No competitor videos found.',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ] else
                              const Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Analyzing channel data...'),
                                  ],
                                ),
                              ),

                            // Similar Channels Section
                            if (_channel != null) ...[
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Similar Channels',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 16),
                                      if (similarChannels.isNotEmpty) ...[
                                        ..._buildChannelList(
                                          similarChannels,
                                        ),
                                      ] else ...[
                                        const Center(
                                          child: Text(
                                            'No similar channels found.',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Text(
                        'Enter a channel URL or username to analyze',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                ],
              ),
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
}
