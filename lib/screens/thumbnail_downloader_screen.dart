import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tubegrow/services/youtube_service.dart';
import '../constants/app_config.dart';
import '../models/video.dart';

class ThumbnailDownloaderScreen extends StatefulWidget {
  const ThumbnailDownloaderScreen({super.key});

  @override
  State<ThumbnailDownloaderScreen> createState() =>
      _ThumbnailDownloaderScreenState();
}

class _ThumbnailDownloaderScreenState extends State<ThumbnailDownloaderScreen> {
  final _urlController = TextEditingController();
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  Video? _video;
  bool _isLoading = false;
  String? _error;
  Map<String, String> _thumbnailUrls = {};
  final Map<String, bool> _downloadStatus = {};

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError:');
      debugPrint(details.toString());
      if (details.exceptionAsString().contains('setState') && !mounted) {
        // Ignore setState after dispose
        return;
      }
      // Optionally, show a dialog or snackbar here
    };
  }

  void _showThumbnailViewer(String quality, String url) {
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(20.0),
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // Reset orientation when closing
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<bool> _requestMediaPermission() async {
    if (!Platform.isAndroid) {
      return true; // iOS and other platforms handle permissions differently
    }

    try {
      final androidVersion = await _getAndroidVersion();

      // For Android 13+ (Android version 13 and above), DO NOT request storage permission, only photos
      // Note: `_getAndroidVersion()` returns the Android major version (e.g. 13), not API level.
      if (androidVersion >= 13) {
        final photos = await Permission.photos.request();

        // Show rationale if needed
        if (photos.isDenied &&
            await Permission.photos.shouldShowRequestRationale) {
          if (mounted) {
            _showPermissionDialog(
              'Photos Permission Required',
              'This app needs access to your photos to save downloaded thumbnails to your gallery. The permission is only used for saving images you choose to download.',
            );
          }
        }

        if (!photos.isGranted) {
          if (mounted) {
            _showErrorSnackBar(
              'Photos permission required to save thumbnails to gallery. You can grant it in Settings.',
            );
          }
          return false;
        }
        return true;
      } else {
        // Android 12 and below
        // Only request storage permission for Android 12 and below
        final storage = await Permission.storage.request();

        if (storage.isDenied &&
            await Permission.storage.shouldShowRequestRationale) {
          if (mounted) {
            _showPermissionDialog(
              'Storage Permission Required',
              'This app needs access to your device storage to save downloaded thumbnails. The permission is only used for saving images you choose to download.',
            );
          }
        }

        // if (!storage.isGranted) {
        //   if (mounted) {
        //     _showErrorSnackBar(
        //       'Storage permission required to download thumbnails. You can grant it in Settings.',
        //     );
        //   }
        //   return false;
        // }
        return true;
      }
    } catch (e) {
      debugPrint('Permission error: $e');
      if (mounted) {
        _showErrorSnackBar('Permission error: Unable to request permissions');
      }
      return false;
    }
  }

  void _showPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    final version = Platform.version;
    final match = RegExp(r'Android (\d+)').firstMatch(version);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0;
  }

  Future<void> _getVideoDetails() async {
    if (_urlController.text.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _video = null;
      _thumbnailUrls.clear();
      _downloadStatus.clear();
    });

    try {
      await Future.any([
        _getVideoDetailsInternal(),
        Future.delayed(const Duration(seconds: 15), () {
          throw Exception(
            'Timeout: Operation took too long. Please try again.',
          );
        }),
      ]);
    } catch (e, stack) {
      debugPrint('ThumbnailDownloader error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _getVideoDetailsInternal() async {
    try {
      String input = _urlController.text.trim();
      String? videoId;

      // Robust video ID extraction
      try {
        final uri = Uri.parse(input);
        if (uri.host.contains('youtube.com')) {
          if (uri.queryParameters.containsKey('v')) {
            // youtube.com/watch?v=ID
            videoId = uri.queryParameters['v'];
          } else if (uri.path.contains('/shorts/')) {
            // youtube.com/shorts/ID
            videoId = uri.pathSegments[uri.pathSegments.indexOf('shorts') + 1];
          }
        } else if (uri.host.contains('youtu.be')) {
          // youtu.be/ID
          videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        }
      } catch (e) {
        // Fallback to service extraction
        videoId = _youtubeService.extractVideoId(input);
      }

      // Fallback if still not found
      videoId ??= _youtubeService.extractVideoId(input);
      if (videoId == null || videoId.isEmpty) {
        throw Exception('Invalid YouTube URL');
      }

      // Add timeout to API calls
      final video = await _youtubeService.getVideoDetails(videoId).timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('Timeout: Could not fetch video details.'),
          );

      final thumbnails =
          await _youtubeService.getVideoThumbnails(videoId).timeout(
                const Duration(seconds: 10),
                onTimeout: () =>
                    throw Exception('Timeout: Could not fetch thumbnails.'),
              );

      // Add fallback thumbnail generation if service doesn't return them
      if (thumbnails.isEmpty) {
        _generateFallbackThumbnails(videoId);
      }

      if (!mounted) return;
      setState(() {
        _video = video;
        _thumbnailUrls = thumbnails.isEmpty
            ? _generateFallbackThumbnails(videoId!)
            : thumbnails;
        _isLoading = false;
      });
    } catch (e) {
      rethrow;
    }
  }

  // Generate fallback thumbnails using YouTube's standard thumbnail URLs
  Map<String, String> _generateFallbackThumbnails(String videoId) {
    return {
      'default': 'https://img.youtube.com/vi/$videoId/default.jpg',
      'medium': 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
      'high': 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      'standard': 'https://img.youtube.com/vi/$videoId/sddefault.jpg',
      'maxres': 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
    };
  }

  Future<void> _downloadThumbnail(String quality, String url) async {
    // Check if already downloading
    if (_downloadStatus[quality] == true) {
      return;
    }

    setState(() => _downloadStatus[quality] = true);

    try {
      final androidVersion = await _getAndroidVersion();

      // For Android 13+ (API 33+), skip permission check and save directly to gallery
      if (Platform.isAndroid && androidVersion >= 33) {
        // Download the image
        final response = await Dio().get(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            validateStatus: (status) => status! < 500,
          ),
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to download image: HTTP ${response.statusCode}',
          );
        }

        final imageBytes = response.data as List<int>;

        // Generate a clean filename
        String videoTitle = _video?.title ?? 'YouTube_Thumbnail';
        final int maxLen = videoTitle.length > 50 ? 50 : videoTitle.length;
        String cleanTitle = videoTitle
            .replaceAll(RegExp(r'[<>:"/\\|?*\[\]]'), '_')
            .replaceAll(RegExp(r'\s+'), '_')
            .substring(0, maxLen);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${cleanTitle}_${quality}_$timestamp.jpg';

        // Save using MediaStore API only, no storage permission required
        await _saveToMediaStore(imageBytes, fileName, quality);
      } else {
        // For Android 12 and below (major version < 13), request permission as before
        if (!await _requestMediaPermission()) {
          setState(() => _downloadStatus[quality] = false);
          return;
        }

        // Download the image
        final response = await Dio().get(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            validateStatus: (status) => status! < 500,
          ),
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to download image: HTTP ${response.statusCode}',
          );
        }

        final imageBytes = response.data as List<int>;

        // Generate a clean filename
        String videoTitle = _video?.title ?? 'YouTube_Thumbnail';
        final int maxLen2 = videoTitle.length > 50 ? 50 : videoTitle.length;
        String cleanTitle = videoTitle
            .replaceAll(RegExp(r'[<>:"/\\|?*\[\]]'), '_')
            .replaceAll(RegExp(r'\s+'), '_')
            .substring(0, maxLen2);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${cleanTitle}_${quality}_$timestamp.jpg';

        await _saveToMediaStore(imageBytes, fileName, quality);
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        _handleDownloadError(e, quality, url);
      }
    } finally {
      if (mounted) {
        setState(() => _downloadStatus[quality] = false);
      }
    }
  }

  Future<void> _saveToMediaStore(
    List<int> imageBytes,
    String fileName,
    String quality,
  ) async {
    try {
      // Use ImageGallerySaver for all platforms and Android versions
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(imageBytes),
        quality: 100,
        name: fileName,
        isReturnImagePathOfIOS: true,
      );

      debugPrint('ImageGallerySaver result: $result');

      // Check for success in various result formats
      final isSuccess = _isDownloadSuccessful(result);

      if (isSuccess) {
        if (mounted) {
          _showSuccessSnackBar(fileName, quality, result);
        }
      } else {
        throw Exception('Failed to save to gallery. Result: $result');
      }
    } catch (e) {
      debugPrint('MediaStore save error: $e');
      rethrow;
    }
  }

  bool _isDownloadSuccessful(dynamic result) {
    if (result == null) return false;

    if (result is Map) {
      // Check various success indicators
      return (result['isSuccess'] == true) ||
          (result['filePath'] != null &&
              result['filePath'].toString().isNotEmpty) ||
          (result['file'] != null && result['file'].toString().isNotEmpty) ||
          (result['errorMessage'] == null);
    } else if (result is String) {
      // If result is a string path, consider it successful
      return result.isNotEmpty;
    } else if (result is bool) {
      return result;
    }

    return false;
  }

  void _showSuccessSnackBar(String fileName, String quality, dynamic result) {
    String locationMessage = 'Gallery';

    if (result is Map && result['filePath'] != null) {
      locationMessage = 'Gallery (${result['filePath']})';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✓ Thumbnail saved successfully!'),
            const SizedBox(height: 4),
            Text(
              'Quality: $quality',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            Text(
              'Location: $locationMessage',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Open Gallery',
          textColor: Colors.white,
          onPressed: () {
            _showGalleryInstructions();
          },
        ),
      ),
    );
  }

  void _showGalleryInstructions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Check your Photos app, Gallery, or Downloads folder'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _handleDownloadError(dynamic error, String quality, String url) {
    String errorMessage = 'Download failed';

    if (error.toString().contains('Permission denied')) {
      errorMessage =
          'Permission denied. Please check app permissions in Settings.';
    } else if (error.toString().contains('No space left')) {
      errorMessage = 'Not enough storage space on device.';
    } else if (error.toString().contains('Network') ||
        error.toString().contains('SocketException')) {
      errorMessage = 'Network error. Please check your internet connection.';
    } else if (error.toString().contains('HTTP')) {
      errorMessage = 'Failed to download image. Please try again.';
    } else if (error.toString().contains('timeout')) {
      errorMessage = 'Download timed out. Please try again.';
    } else {
      errorMessage = 'Download failed: ${error.toString()}';
    }

    _showErrorSnackBar(errorMessage, () => _downloadThumbnail(quality, url));
  }

  void _showErrorSnackBar(String message, [VoidCallback? onRetry]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  Widget _buildThumbnailItem(String quality, String url) {
    return GestureDetector(
      onTap: () => _showThumbnailViewer(quality, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.error)),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      quality.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _getResolutionText(quality),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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

  String _getResolutionText(String quality) {
    switch (quality) {
      case 'maxres':
        return '1920×1080';
      case 'standard':
        return '640×480';
      case 'high':
        return '480×360';
      case 'medium':
        return '320×180';
      case 'default':
        return '120×90';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Thumbnails Analyzer'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'Enter YouTube video URL',
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _getVideoDetails,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) => _getVideoDetails(),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Fetching video details...'),
                            ],
                          ),
                        ),
                      )
                    else if (_error != null)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _getVideoDetails,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_video != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.video_library),
                                title: Text(
                                  _video!.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(_video!.channelTitle),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Available Thumbnails (${_thumbnailUrls.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (_thumbnailUrls.isEmpty)
                              const Expanded(
                                child: Center(
                                  child: Text('No thumbnails found.'),
                                ),
                              )
                            else
                              Expanded(
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 16 / 9,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: _thumbnailUrls.length,
                                  itemBuilder: (context, index) {
                                    final entry =
                                        _thumbnailUrls.entries.elementAt(index);
                                    return _buildThumbnailItem(
                                      entry.key,
                                      entry.value,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_search,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Enter a YouTube video URL to get thumbnails',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      );
    } catch (e, stack) {
      debugPrint('Build error: $e\n$stack');
      return Scaffold(
        appBar: AppBar(title: const Text('Thumbnail Downloader')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('A build error occurred: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
  }
}
