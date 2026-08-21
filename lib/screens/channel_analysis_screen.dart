import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/youtube_service.dart';
import '../constants/app_config.dart';
import '../models/channel.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ChannelAnalysisScreen extends StatefulWidget {
  final String channelUrl;
  const ChannelAnalysisScreen({super.key, required this.channelUrl});

  @override
  State<ChannelAnalysisScreen> createState() => _ChannelAnalysisScreenState();
}

class _ChannelAnalysisScreenState extends State<ChannelAnalysisScreen>
    with SingleTickerProviderStateMixin {
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  late TabController _tabController;
  Channel? _channel;
  List<Video> _videos = [];
  List<String> _commonTags = [];
  List<Channel> _similarChannels = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadChannelData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChannelData() async {
    try {
      setState(() => _isLoading = true);

      // Extract channel ID from URL
      String channelId = await _youtubeService.getChannelId(widget.channelUrl);

      // Load channel details and videos in parallel
      final results = await Future.wait([
        _youtubeService.getChannelDetails(channelId),
        _youtubeService.getChannelVideos(channelId),
      ]);

      final channelData = results[0] as Map<String, dynamic>;
      final videos = results[1] as List<Video>;

      // Extract common tags from videos
      final tagFrequency = <String, int>{};
      for (var video in videos) {
        for (var tag in video.tags) {
          tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
        }
      }

      // Sort tags by frequency
      final sortedTags =
          tagFrequency.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _channel = Channel.fromJson(channelData);
        _videos = videos;
        _commonTags = sortedTags.take(20).map((e) => e.key).toList();
        _isLoading = false;
      });

      // Load similar channels in background
      _loadSimilarChannels();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSimilarChannels() async {
    try {
      if (_channel == null) return;
      final channels = await _youtubeService.searchChannels(_channel!.title);
      setState(
        () =>
            _similarChannels =
                channels..removeWhere((c) => c.id == _channel!.id),
      );
    } catch (e) {
      // Silently fail for similar channels
      debugPrint('Failed to load similar channels: $e');
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildOverviewTab() {
    if (_channel == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_channel!.bannerUrl.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(_channel!.bannerUrl, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: () => _downloadChannelArt(true),
                      tooltip: 'Download Banner',
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(_channel!.thumbnailUrl),
                  ),
                  Positioned(
                    right: -8,
                    bottom: -8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.download,
                          size: 16,
                          color: Colors.white,
                        ),
                        onPressed: () => _downloadChannelArt(false),
                        tooltip: 'Download Avatar',
                        iconSize: 16,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),
                ],
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
                    if (_channel!.country.isNotEmpty)
                      Text(
                        'Country: ${_channel!.country}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatRow(
                    'Subscribers',
                    _formatNumber(_channel!.subscriberCount),
                  ),
                  const Divider(),
                  _buildStatRow(
                    'Total Videos',
                    _formatNumber(_channel!.videoCount),
                  ),
                  const Divider(),
                  _buildStatRow(
                    'Total Views',
                    _formatNumber(_channel!.viewCount),
                  ),
                  const Divider(),
                  _buildStatRow(
                    'Avg. Views per Video',
                    _formatNumber(_channel!.viewCount ~/ _channel!.videoCount),
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
              child: Text(_channel!.description),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosTab() {
    if (_videos.isEmpty) {
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
      padding: const EdgeInsets.all(16),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VideoCard(video: _videos[index]),
        );
      },
    );
  }

  Widget _buildTagsTab() {
    if (_commonTags.isEmpty) {
      return const Center(child: Text('No common tags found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Most Used Tags', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _commonTags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
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
    );
  }

  Widget _buildCompetitorsTab() {
    if (_similarChannels.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No similar channels found', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _similarChannels.length,
      itemBuilder: (context, index) {
        final channel = _similarChannels[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(channel.thumbnailUrl),
            ),
            title: Text(channel.title),
            subtitle: Text(
              'Subscribers: ${_formatNumber(channel.subscriberCount)}',
            ),
            trailing: Text('Videos: ${_formatNumber(channel.videoCount)}'),
          ),
        );
      },
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

  Future<void> _downloadChannelArt(bool isBanner) async {
    try {
      final url = isBanner ? _channel!.bannerUrl : _channel!.thumbnailUrl;
      final type = isBanner ? 'banner' : 'avatar';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download $type');
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = '${_channel!.title}_$type.jpg';
      final sanitizedFileName = fileName.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );
      final file = File('${dir.path}/$sanitizedFileName');

      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Channel $type downloaded successfully!'),
            action: SnackBarAction(
              label: 'Share',
              onPressed:
                  () => Share.share(
                    file.path,
                    subject: 'Channel $type',
                  ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Analysis'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Videos'),
            Tab(text: 'Common Tags'),
            Tab(text: 'Similar Channels'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(
                  'Error: $_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildVideosTab(),
                  _buildTagsTab(),
                  _buildCompetitorsTab(),
                ],
              ),
    );
  }
}
