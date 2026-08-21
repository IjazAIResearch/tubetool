import 'package:flutter/material.dart';
import '../services/youtube_service.dart';
import '../constants/app_config.dart';
import '../models/channel.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import '../services/youtube_url_service.dart';
class ChannelExplorerScreen extends StatefulWidget {
  const ChannelExplorerScreen({super.key});

  @override
  State<ChannelExplorerScreen> createState() => _ChannelExplorerScreenState();
}

class _ChannelExplorerScreenState extends State<ChannelExplorerScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  Channel? _channel;
  List<Video> _videos = [];
  bool _isLoading = false;
  String? _error;
  late TabController _tabController;
  final String _sortBy = 'date'; // 'date', 'views', 'likes'
  final String _videoType = 'all'; // 'all', 'short', 'long'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _searchChannel() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _channel = null;
      _videos.clear();
    });
    try {
      final input = _searchController.text.trim();
      String? channelId;

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

      final channelData = await _youtubeService.getChannelDetails(channelId);
      final videos = await _youtubeService.getChannelVideos(channelId);

      setState(() {
        _channel = Channel.fromJson(channelData);
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Video> get _filteredVideos {
    var filtered = List<Video>.from(_videos);

    // Filter by video type
    if (_videoType == 'short') {
      filtered = filtered.where((v) => v.duration.inMinutes < 5).toList();
    } else if (_videoType == 'long') {
      filtered = filtered.where((v) => v.duration.inMinutes >= 5).toList();
    }

    // Sort videos
    switch (_sortBy) {
      case 'date':
        filtered.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        break;
      case 'views':
        filtered.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      case 'likes':
        filtered.sort((a, b) => b.likeCount.compareTo(a.likeCount));
        break;
    }

    return filtered;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Explorer'),
        bottom:
            _channel != null
                ? TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Videos'),
                    Tab(text: 'Analytics'),
                  ],
                )
                : null,
      ),
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
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Overview Tab
                    _buildOverviewTab(),
                    // Videos Tab
                    _buildVideosTab(),
                    // Analytics Tab
                    _buildAnalyticsTab(),
                  ],
                ),
              )
            else
              const Center(
                child: Text(
                  'Enter a channel URL or username to explore',
                  style: TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(_channel!.thumbnailUrl),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _channel!.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_channel!.formattedSubscriberCount} subscribers',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          '${_channel!.videoCount} videos • ${_channel!.formattedViewCount} views',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Channel Description
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_channel!.description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final filteredVideos = _filteredVideos;
    if (filteredVideos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No videos found', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: filteredVideos.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VideoCard(video: filteredVideos[index]),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    if (_videos.isEmpty) {
      return const Center(child: Text('No videos available for analysis'));
    }

    // Calculate basic analytics
    final totalViews = _videos.fold<int>(
      0,
      (sum, video) => sum + video.viewCount,
    );
    final totalLikes = _videos.fold<int>(
      0,
      (sum, video) => sum + video.likeCount,
    );
    final avgViews = totalViews ~/ _videos.length;
    final avgLikes = totalLikes ~/ _videos.length;
    final avgEngagement = (totalLikes / totalViews * 100).toStringAsFixed(2);

    // Earnings calculations (if monetized)
    final isMonetized =
        _channel!.viewCount > 4000 && _channel!.subscriberCount >= 1000;
    const estimatedCPM = 2.0; // Average CPM in USD
    final monetizedViews =
        (totalViews * 0.6).toInt(); // Assuming 60% of views are monetized
    final monthlyEarnings = (monetizedViews / 1000 * estimatedCPM)
        .toStringAsFixed(2);
    final yearlyEarnings = (double.parse(monthlyEarnings) * 12).toStringAsFixed(
      2,
    );

    // Find most successful video
    final mostViewedVideo = _videos.reduce(
      (a, b) => a.viewCount > b.viewCount ? a : b,
    );
    return SingleChildScrollView(
      child: Column(
        children: [
          // Monetization Status Card
          if (isMonetized)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Channel is Monetized',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow(
                      'Est. Monthly Earnings',
                      '\$$monthlyEarnings',
                    ),
                    _buildStatRow('Est. Yearly Earnings', '\$$yearlyEarnings'),
                    const SizedBox(height: 8),
                    Text(
                      'Based on average CPM of \$$estimatedCPM',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.money_off, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Channel is Not Monetized',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Requirements for monetization:\n• 1,000+ subscribers\n• 4,000+ watch hours',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Performance Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Channel Performance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Total Views', totalViews.toString()),
                  _buildStatRow('Average Views', avgViews.toString()),
                  _buildStatRow('Average Likes', avgLikes.toString()),
                  _buildStatRow('Engagement Rate', '$avgEngagement%'),
                  _buildStatRow(
                    'Upload Frequency',
                    '${(_videos.length / 30).toStringAsFixed(1)} videos/month',
                  ),
                  _buildStatRow('Country', _channel!.country),
                  _buildStatRow('Joined', _formatDate(_channel!.joinedDate)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Video Performance Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video Performance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  // Most viewed video
                  Text(
                    'Most Viewed Video',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  VideoCard(
                    video: mostViewedVideo,
                    onTap: () {
                      // Handle video tap
                    },
                  ),
                  const SizedBox(height: 16),
                  // Latest video
                  Text(
                    'Latest Video',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  VideoCard(
                    video: _videos.reduce(
                      (a, b) => a.publishedAt.isAfter(b.publishedAt) ? a : b,
                    ),
                    onTap: () {
                      // Handle video tap
                    },
                  ),
                  if (isMonetized) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Estimated Earnings (Most Viewed Video)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    _buildStatRow(
                      'Views Revenue',
                      '\$${((mostViewedVideo.viewCount * 0.6) / 1000 * estimatedCPM).toStringAsFixed(2)}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Audience Insights Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audience Insights',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Main Audience Region', _channel!.country),
                  _buildStatRow(
                    'Average View Duration',
                    '${(mostViewedVideo.duration.inMinutes * 0.4).toStringAsFixed(1)} minutes',
                  ),
                  _buildStatRow(
                    'Subscriber Growth',
                    '${(_channel!.subscriberCount / _videos.length).toStringAsFixed(0)} per video',
                  ),
                  _buildStatRow(
                    'Comments per Video',
                    (_videos.fold<int>(0, (sum, v) => sum + v.commentCount) /
                            _videos.length)
                        .toStringAsFixed(1),
                  ),
                ],
              ),
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
}
