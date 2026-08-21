import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubegrow/constants/app_config.dart';
import 'package:tubegrow/models/video.dart';
import 'package:tubegrow/services/youtube_service.dart';
import 'package:tubegrow/widgets/video_card.dart';

class TrendingVideosScreen extends StatefulWidget {
  const TrendingVideosScreen({super.key});

  @override
  State<TrendingVideosScreen> createState() => _TrendingVideosScreenState();
}

class _TrendingVideosScreenState extends State<TrendingVideosScreen> {
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  final _searchController = TextEditingController();
  List<Video>? _videos;
  String _selectedCountry = 'US';
  bool _isLoading = false;
  String? _error;
  String _countrySearchQuery = '';

  final Map<String, String> _countries = {
    'AF': 'Afghanistan',
    'AL': 'Albania',
    'DZ': 'Algeria',
    'AR': 'Argentina',
    'AU': 'Australia',
    'AT': 'Austria',
    'BH': 'Bahrain',
    'BD': 'Bangladesh',
    'BE': 'Belgium',
    'BO': 'Bolivia',
    'BA': 'Bosnia and Herzegovina',
    'BR': 'Brazil',
    'BG': 'Bulgaria',
    'KH': 'Cambodia',
    'CA': 'Canada',
    'CL': 'Chile',
    'CN': 'China',
    'CO': 'Colombia',
    'CR': 'Costa Rica',
    'HR': 'Croatia',
    'CY': 'Cyprus',
    'CZ': 'Czech Republic',
    'DK': 'Denmark',
    'DO': 'Dominican Republic',
    'EC': 'Ecuador',
    'EG': 'Egypt',
    'SV': 'El Salvador',
    'EE': 'Estonia',
    'FI': 'Finland',
    'FR': 'France',
    'GE': 'Georgia',
    'DE': 'Germany',
    'GH': 'Ghana',
    'GR': 'Greece',
    'GT': 'Guatemala',
    'HN': 'Honduras',
    'HK': 'Hong Kong',
    'HU': 'Hungary',
    'IS': 'Iceland',
    'IN': 'India',
    'ID': 'Indonesia',
    'IQ': 'Iraq',
    'IE': 'Ireland',
    'IL': 'Israel',
    'IT': 'Italy',
    'JM': 'Jamaica',
    'JP': 'Japan',
    'JO': 'Jordan',
    'KZ': 'Kazakhstan',
    'KE': 'Kenya',
    'KW': 'Kuwait',
    'LV': 'Latvia',
    'LB': 'Lebanon',
    'LY': 'Libya',
    'LI': 'Liechtenstein',
    'LT': 'Lithuania',
    'LU': 'Luxembourg',
    'MK': 'Macedonia',
    'MY': 'Malaysia',
    'MT': 'Malta',
    'MX': 'Mexico',
    'ME': 'Montenegro',
    'MA': 'Morocco',
    'NP': 'Nepal',
    'NL': 'Netherlands',
    'NZ': 'New Zealand',
    'NI': 'Nicaragua',
    'NG': 'Nigeria',
    'NO': 'Norway',
    'OM': 'Oman',
    'PK': 'Pakistan',
    'PA': 'Panama',
    'PG': 'Papua New Guinea',
    'PY': 'Paraguay',
    'PE': 'Peru',
    'PH': 'Philippines',
    'PL': 'Poland',
    'PT': 'Portugal',
    'PR': 'Puerto Rico',
    'QA': 'Qatar',
    'RO': 'Romania',
    'RU': 'Russia',
    'SA': 'Saudi Arabia',
    'SN': 'Senegal',
    'RS': 'Serbia',
    'SG': 'Singapore',
    'SK': 'Slovakia',
    'SI': 'Slovenia',
    'ZA': 'South Africa',
    'KR': 'South Korea',
    'ES': 'Spain',
    'LK': 'Sri Lanka',
    'SE': 'Sweden',
    'CH': 'Switzerland',
    'TW': 'Taiwan',
    'TZ': 'Tanzania',
    'TH': 'Thailand',
    'TN': 'Tunisia',
    'TR': 'Turkey',
    'UG': 'Uganda',
    'UA': 'Ukraine',
    'AE': 'United Arab Emirates',
    'GB': 'United Kingdom',
    'US': 'United States',
    'UY': 'Uruguay',
    'VE': 'Venezuela',
    'VN': 'Vietnam',
    'YE': 'Yemen',
    'ZW': 'Zimbabwe',
  };

  Map<String, String> get _filteredCountries =>
      _countries.map((code, name) => MapEntry(code, name))..removeWhere(
        (code, name) =>
            !name.toLowerCase().contains(_countrySearchQuery.toLowerCase()) &&
            !code.toLowerCase().contains(_countrySearchQuery.toLowerCase()),
      );

  @override
  void initState() {
    super.initState();
    _fetchTrendingVideos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrendingVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final videos = await _youtubeService.getTrendingVideos(_selectedCountry);
      setState(() {
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

  Widget _buildVideoList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_videos == null || _videos!.isEmpty) {
      return const Center(child: Text('No videos found'));
    }

    return ListView.builder(
      itemCount: _videos!.length,
      itemBuilder: (context, index) {
        final video = _videos![index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: VideoCard(
            video: video,
            onTap: () => _showVideoDetails(video),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trending Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.public),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder:
                    (context) => StatefulBuilder(
                      builder:
                          (context, setState) => AlertDialog(
                            title: const Text('Select Country'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    decoration: const InputDecoration(
                                      hintText: 'Search countries...',
                                      prefixIcon: Icon(Icons.search),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      setState(
                                        () => _countrySearchQuery = value,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _filteredCountries.length,
                                      itemBuilder: (context, index) {
                                        final entry = _filteredCountries.entries
                                            .elementAt(index);
                                        return ListTile(
                                          leading: Text(entry.key),
                                          title: Text(entry.value),
                                          selected:
                                              _selectedCountry == entry.key,
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            setState(() {
                                              _selectedCountry = entry.key;
                                              _countrySearchQuery = '';
                                            });
                                            _fetchTrendingVideos();
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTrendingVideos,
        child: _buildVideoList(),
      ),
    );
  }

  void _showVideoDetails(Video video) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Channel: ${video.channelTitle}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Views: ${_formatNumber(video.viewCount)} • Likes: ${_formatNumber(video.likeCount)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Divider(height: 24),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(video.description),
                      if (video.tags.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'Tags',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              video.tags
                                  .map(
                                    (tag) => Chip(
                                      label: Text(tag),
                                      onDeleted: () {
                                        Clipboard.setData(
                                          ClipboardData(text: tag),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Copied "$tag" to clipboard',
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
                    ],
                  ),
                ),
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
