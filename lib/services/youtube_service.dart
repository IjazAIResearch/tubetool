import 'package:dio/dio.dart';
import '../models/video.dart';
import '../models/channel.dart';
import '../models/comment.dart';
import '../constants/app_config.dart';

class YouTubeService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://www.googleapis.com/youtube/v3';
  String _apiKey;

  YouTubeService(this._apiKey);

  // Handle API key rotation when quota is exceeded
  Future<Response<T>> _makeRequest<T>(
    String path, {
    required Map<String, dynamic> queryParameters,
    Options? options,
    int retryCount = 0,
  }) async {
    try {
      final response = await _dio.get<T>(
        '$_baseUrl/$path',
        queryParameters: {...queryParameters, 'key': _apiKey},
        options: options ?? Options(validateStatus: (status) => status! < 500),
      );

      // Check for quota exceeded error
      if (response.statusCode == 403) {
        final error =
            response.data is Map ? (response.data as Map)['error'] : null;
        if (error != null && error['errors'] is List) {
          final errors = error['errors'] as List;
          if (errors.any((e) => e['reason'] == 'quotaExceeded')) {
            // Mark current key as exhausted
            AppConfig.markKeyAsExhausted(_apiKey);

            // Try switching to next API key
            final nextKey = AppConfig.switchToNextApiKey();
            if (nextKey != null &&
                retryCount < AppConfig.youtubeApiKeys.length) {
              _apiKey = nextKey;
              // Retry the request with new API key
              return await _makeRequest<T>(
                path,
                queryParameters: queryParameters,
                options: options,
                retryCount: retryCount + 1,
              );
            } else {
              throw DioError(
                requestOptions: RequestOptions(path: path),
                error: 'All API keys have exceeded their quota.',
              );
            }
          }
        }
      }

      return response;
    } on DioError catch (e) {
      if (e.response?.statusCode == 403) {
        final error = e.response?.data['error'];
        if (error != null && error['errors'] is List) {
          final errors = error['errors'] as List;
          if (errors.any((e) => e['reason'] == 'quotaExceeded')) {
            // Switch to next API key
            AppConfig.switchToNextApiKey();
            _apiKey = AppConfig.youtubeApiKey;

            // Retry the request with new API key
            return await _dio.get<T>(
              '$_baseUrl/$path',
              queryParameters: {...queryParameters, 'key': _apiKey},
              options: options,
            );
          }
        }
      }
      rethrow;
    }
  }

  Future<List<Video>> searchVideos(
    String query, {
    String regionCode = 'US',
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'part': 'snippet',
          'q': query,
          'type': 'video',
          'maxResults': 25,
          'key': _apiKey,
          'regionCode': regionCode,
          'videoSyndicated': 'true',
          'videoEmbeddable': 'true',
        },
      );

      final items = response.data['items'] as List;
      final videoIds = items.map((item) => item['id']['videoId']).join(',');

      final videoResponse = await _dio.get(
        '$_baseUrl/videos',
        queryParameters: {
          'part': 'snippet,statistics,contentDetails',
          'id': videoIds,
          'key': _apiKey,
        },
      );

      return (videoResponse.data['items'] as List)
          .map((item) => Video.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to search videos: $e');
    }
  }

  Future<Video> getVideoDetails(String videoId) async {
    try {
      final response = await _makeRequest<Map<String, dynamic>>(
        'videos',
        queryParameters: {
          'part': 'snippet,statistics,contentDetails',
          'id': videoId,
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get video details: HTTP ${response.statusCode}',
        );
      }

      final items = response.data?['items'] as List? ?? [];
      if (items.isEmpty) {
        throw Exception('Video not found');
      }

      return Video.fromJson(items.first);
    } catch (e) {
      throw Exception('Failed to get video details: $e');
    }
  }

  Future<List<Video>> getTrendingVideos(String regionCode) async {
    try {
      final response = await _makeRequest<Map<String, dynamic>>(
        'videos',
        queryParameters: {
          'part': 'snippet,statistics,contentDetails',
          'chart': 'mostPopular',
          'regionCode': regionCode,
          'maxResults': 25,
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get trending videos: HTTP ${response.statusCode}',
        );
      }

      final items = response.data?['items'] as List? ?? [];
      return items.map((item) => Video.fromJson(item)).toList();
    } catch (e) {
      throw Exception('Failed to get trending videos: $e');
    }
  }

  Future<List<String>> suggestTags(String keyword) async {
    try {
      // First, get videos related to the keyword
      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'part': 'snippet',
          'q': keyword,
          'type': 'video',
          'maxResults': 5,
          'key': _apiKey,
          'videoSyndicated': 'true',
          'videoEmbeddable': 'true',
        },
      );

      final items = response.data['items'] as List;
      final videoIds = items.map((item) => item['id']['videoId']).join(',');

      // Then get the details of those videos to extract their tags
      final videoResponse = await _dio.get(
        '$_baseUrl/videos',
        queryParameters: {'part': 'snippet', 'id': videoIds, 'key': _apiKey},
      );

      // Collect all unique tags
      final Set<String> tags = {};
      for (var item in videoResponse.data['items']) {
        final videoTags = (item['snippet']['tags'] ?? []) as List;
        tags.addAll(videoTags.cast<String>());
      }

      // Sort tags by frequency (if we had them) and relevance to the keyword
      final sortedTags =
          tags.toList()..sort((a, b) {
            final aContains = a.toLowerCase().contains(keyword.toLowerCase());
            final bContains = b.toLowerCase().contains(keyword.toLowerCase());
            if (aContains && !bContains) return -1;
            if (!aContains && bContains) return 1;
            return a.compareTo(b);
          });

      return sortedTags;
    } catch (e) {
      throw Exception('Failed to suggest tags: $e');
    }
  }

  Future<Map<String, dynamic>> getChannelDetails(String channelId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/channels',
        queryParameters: {
          'part': 'snippet,statistics,brandingSettings',
          'id': channelId,
          'key': _apiKey,
        },
      );

      final items = response.data['items'] as List;
      if (items.isEmpty) {
        throw Exception('Channel not found');
      }

      return items.first;
    } catch (e) {
      throw Exception('Failed to get channel details: $e');
    }
  }

  Future<List<Comment>> getVideoComments(
    String videoId, {
    String? pageToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/commentThreads',
        queryParameters: {
          'part': 'snippet,replies',
          'videoId': videoId,
          'maxResults': 100,
          'key': _apiKey,
          if (pageToken != null) 'pageToken': pageToken,
        },
      );

      final items = response.data['items'] as List;
      final comments = <Comment>[];

      for (var item in items) {
        comments.add(Comment.fromJson(item['snippet']['topLevelComment']));

        // Add replies if they exist
        if (item['replies'] != null) {
          final replies =
              (item['replies']['comments'] as List)
                  .map((reply) => Comment.fromJson(reply))
                  .toList();
          comments.addAll(replies);
        }
      }

      return comments;
    } catch (e) {
      throw Exception('Failed to get video comments: $e');
    }
  }

  Future<Channel> getChannel(String channelId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/channels',
        queryParameters: {
          'part': 'snippet,statistics,brandingSettings',
          'id': channelId,
          'key': _apiKey,
        },
      );

      final items = response.data['items'] as List;
      if (items.isEmpty) {
        throw Exception('Channel not found');
      }

      return Channel.fromJson(items.first);
    } catch (e) {
      throw Exception('Failed to get channel: $e');
    }
  }

  Future<List<Video>> getChannelVideos(
    String channelId, {
    String? pageToken,
  }) async {
    try {
      // First get playlist ID of channel uploads
      final channelResponse = await _dio.get(
        '$_baseUrl/channels',
        queryParameters: {
          'part': 'contentDetails',
          'id': channelId,
          'key': _apiKey,
        },
      );

      final uploadsPlaylistId =
          channelResponse
              .data['items'][0]['contentDetails']['relatedPlaylists']['uploads'];

      // Then get videos from that playlist
      final response = await _dio.get(
        '$_baseUrl/playlistItems',
        queryParameters: {
          'part': 'snippet,contentDetails',
          'playlistId': uploadsPlaylistId,
          'maxResults': 50,
          'key': _apiKey,
          if (pageToken != null) 'pageToken': pageToken,
        },
      );

      final items = response.data['items'] as List;
      final videoIds = items
          .map((item) => item['snippet']['resourceId']['videoId'])
          .join(',');

      // Get full video details
      final videoResponse = await _dio.get(
        '$_baseUrl/videos',
        queryParameters: {
          'part': 'snippet,statistics,contentDetails',
          'id': videoIds,
          'key': _apiKey,
        },
      );

      return (videoResponse.data['items'] as List)
          .map((item) => Video.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get channel videos: $e');
    }
  }

  Future<List<Video>> findCompetitors(Video video) async {
    try {
      // Search for videos with similar title and tags
      final searchTerms =
          video.title
              .split(' ')
              .where((term) => term.length > 3)
              .take(3)
              .toList();

      if (video.tags.isNotEmpty) {
        searchTerms.addAll(video.tags.take(2));
      }

      final searchQuery = searchTerms.join(' ');

      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'part': 'snippet',
          'q': searchQuery,
          'type': 'video',
          'maxResults': 10,
          'key': _apiKey,
          'videoCategoryId': '1', // Change this based on video category
          'videoSyndicated': 'true',
          'videoEmbeddable': 'true',
        },
      );

      final items = response.data['items'] as List;
      final competitorIds = items
          .map((item) => item['id']['videoId'] as String)
          .where((id) => id != video.id) // Exclude the original video
          .join(',');

      if (competitorIds.isEmpty) {
        return [];
      }

      // Get full video details
      final videoResponse = await _dio.get(
        '$_baseUrl/videos',
        queryParameters: {
          'part': 'snippet,statistics,contentDetails',
          'id': competitorIds,
          'key': _apiKey,
        },
      );

      return (videoResponse.data['items'] as List)
          .map((item) => Video.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to find competitor videos: $e');
    }
  }

  String? extractVideoId(String url) {
    try {
      final Uri uri = Uri.parse(url.trim());

      // Handle youtu.be format
      if (uri.host == 'youtu.be') {
        return uri.pathSegments.first;
      }

      // Handle youtube.com formats
      if (uri.host.contains('youtube.com')) {
        // Regular watch URL
        if (uri.queryParameters.containsKey('v')) {
          return uri.queryParameters['v'];
        }

        // Shorts URL
        if (uri.pathSegments.contains('shorts')) {
          return uri.pathSegments[uri.pathSegments.indexOf('shorts') + 1];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, String>> getVideoThumbnails(String videoId) async {
    return {
      'maxres': 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
      'high': 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      'medium': 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
      'default': 'https://img.youtube.com/vi/$videoId/default.jpg',
    };
  }

  Future<List<String>> getKeywordSuggestions(String keyword) async {
    try {
      final response = await _dio.get(
        'https://suggestqueries.google.com/complete/search',
        queryParameters: {'client': 'youtube', 'ds': 'yt', 'q': keyword},
      );

      if (response.data is List &&
          response.data.length > 1 &&
          response.data[1] is List) {
        return (response.data[1] as List).cast<String>();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get keyword suggestions: $e');
    }
  }

  Future<Map<String, List<String>>> getDetailedKeywordSuggestions(
    String keyword,
  ) async {
    try {
      final Map<String, List<String>> suggestions = {
        'Questions': [],
        'How to': [],
        'Reviews': [],
        'Lists': [],
        'Others': [],
      };

      // Get suggestions from Google/YouTube
      final suggestResponse = await Dio().get(
        'https://suggestqueries.google.com/complete/search',
        queryParameters: {'client': 'firefox', 'ds': 'yt', 'q': keyword},
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          responseType: ResponseType.json,
        ),
      );

      List<String> rawSuggestions = [];
      if (suggestResponse.data is List && suggestResponse.data.length > 1) {
        rawSuggestions = (suggestResponse.data[1] as List).cast<String>();
      }

      // Get related video titles
      final videoResponse = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'part': 'snippet',
          'q': keyword,
          'type': 'video',
          'maxResults': 25,
          'key': _apiKey,
        },
      );

      final videoTitles =
          (videoResponse.data['items'] as List).map((item) {
            final title = item['snippet']['title'] as String;
            // Clean up title by removing channel name in brackets/parentheses
            return title.replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), '').trim();
          }).toList();

      // Combine and filter suggestions
      final Set<String> allSuggestions = {...rawSuggestions, ...videoTitles};

      // Categorize suggestions
      for (var suggestion in allSuggestions) {
        final lower = suggestion.toLowerCase();

        // Question pattern
        if (lower.contains('?') ||
            lower.startsWith(
              RegExp(
                r'(what|how|why|when|where|which|who|can|does|is|are|will)',
              ),
            )) {
          suggestions['Questions']!.add(suggestion);
        }
        // How-to pattern
        else if (lower.contains('how to') ||
            lower.contains('tutorial') ||
            lower.contains('guide') ||
            lower.contains('tips') ||
            lower.startsWith('ways to')) {
          suggestions['How to']!.add(suggestion);
        }
        // Review pattern
        else if (lower.contains('review') ||
            lower.contains('vs') ||
            lower.contains('versus') ||
            lower.contains('comparison') ||
            lower.contains('worth it')) {
          suggestions['Reviews']!.add(suggestion);
        }
        // List pattern
        else if (lower.startsWith('top') ||
            lower.startsWith('best') ||
            lower.contains('must have') ||
            lower.contains('essential') ||
            RegExp(r'^\d+\s').hasMatch(lower)) {
          suggestions['Lists']!.add(suggestion);
        } else {
          suggestions['Others']!.add(suggestion);
        }
      }

      // Sort suggestions within each category
      suggestions.forEach((category, list) {
        list.sort((a, b) {
          // Prioritize suggestions containing the keyword
          final aContains = a.toLowerCase().contains(keyword.toLowerCase());
          final bContains = b.toLowerCase().contains(keyword.toLowerCase());
          if (aContains && !bContains) return -1;
          if (!aContains && bContains) return 1;
          // Then sort by length (shorter first)
          return a.length.compareTo(b.length);
        });
      });

      return suggestions;
    } catch (e) {
      throw Exception('Failed to get keyword suggestions: $e');
    }
  }

  Future<String> getChannelId(String input) async {
    try {
      // If input is already a channel ID (starts with UC), return it
      if (input.trim().startsWith('UC') && input.trim().length == 24) {
        return input.trim();
      }

      String searchQuery = input.trim();

      // Handle custom URLs with different formats
      if (searchQuery.contains('youtube.com')) {
        Uri uri = Uri.parse(searchQuery);
        if (uri.pathSegments.contains('channel')) {
          return uri.pathSegments[uri.pathSegments.indexOf('channel') + 1];
        } else if (uri.pathSegments.contains('c') ||
            uri.pathSegments.contains('user')) {
          searchQuery = uri.pathSegments.last;
        } else if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments[0].startsWith('@')) {
          searchQuery = uri.pathSegments[0];
        }
      }

      // Add @ prefix for handle format if needed
      if (!searchQuery.startsWith('@') && !searchQuery.contains('/')) {
        searchQuery = '@$searchQuery';
      }

      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'part': 'snippet',
          'type': 'channel',
          'q': searchQuery,
          'maxResults': 1,
          'key': _apiKey,
        },
      );

      final items = response.data['items'] as List;
      if (items.isEmpty) {
        throw Exception('Channel not found');
      }

      String channelId = items.first['snippet']['channelId'];

      // Verify the channel exists and is accessible
      await _dio.get(
        '$_baseUrl/channels',
        queryParameters: {'part': 'snippet', 'id': channelId, 'key': _apiKey},
      );

      return channelId;
    } catch (e) {
      throw Exception(
        'Failed to get channel ID: Channel not found or inaccessible',
      );
    }
  }

  Future<Channel> getChannelInfo(String channelId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/channels',
        queryParameters: {
          'part': 'snippet,statistics',
          'id': channelId,
          'key': _apiKey,
        },
      );

      final items = response.data['items'] as List;
      if (items.isEmpty) throw Exception('Channel not found');

      return Channel.fromJson(items.first);
    } catch (e) {
      throw Exception('Failed to get channel details: $e');
    }
  }

  Future<List<Video>> getRecentChannelVideos(String channelId) async {
    try {
      // First get upload playlist ID
      final channelResponse = await _dio.get(
        '$_baseUrl/channels',
        queryParameters: {
          'part': 'contentDetails',
          'id': channelId,
          'key': _apiKey,
        },
      );

      final uploadPlaylistId =
          channelResponse
              .data['items'][0]['contentDetails']['relatedPlaylists']['uploads'];

      // Then get videos from upload playlist
      final playlistResponse = await _dio.get(
        '$_baseUrl/playlistItems',
        queryParameters: {
          'part': 'snippet,contentDetails',
          'playlistId': uploadPlaylistId,
          'maxResults': 50,
          'key': _apiKey,
        },
      );

      final videoIds = (playlistResponse.data['items'] as List)
          .map((item) => item['contentDetails']['videoId'] as String)
          .join(',');

      // Finally get full video details
      final videosResponse = await _dio.get(
        '$_baseUrl/videos',
        queryParameters: {
          'part': 'snippet,statistics,contentDetails',
          'id': videoIds,
          'key': _apiKey,
        },
      );

      return (videosResponse.data['items'] as List)
          .map((item) => Video.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to get channel videos: $e');
    }
  }

  Future<List<Channel>> searchChannels(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'part': 'snippet',
          'q': query,
          'type': 'channel',
          'maxResults': 10,
          'key': _apiKey,
        },
      );

      final items = response.data['items'] as List;
      final channelIds = items
          .map((item) => item['snippet']['channelId'])
          .join(',');

      // Get full channel details
      final channelResponse = await _dio.get(
        '$_baseUrl/channels',
        queryParameters: {
          'part': 'snippet,statistics,brandingSettings',
          'id': channelIds,
          'key': _apiKey,
        },
      );

      return (channelResponse.data['items'] as List)
          .map((item) => Channel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to search channels: $e');
    }
  }
}
