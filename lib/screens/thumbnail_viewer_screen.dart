import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubegrow/services/youtube_service.dart';
import '../constants/app_config.dart';
import '../models/video.dart';

class ThumbnailViewerScreen extends StatefulWidget {
  const ThumbnailViewerScreen({super.key});

  @override
  State<ThumbnailViewerScreen> createState() => _ThumbnailViewerScreenState();
}

class _ThumbnailViewerScreenState extends State<ThumbnailViewerScreen> {
  final _urlController = TextEditingController();
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  Video? _video;
  bool _isLoading = false;
  String? _error;
  Map<String, String> _thumbnailUrls = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _urlController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _fetchVideoData() async {
    if (_urlController.text.isEmpty) {
      setState(() => _error = 'Please enter a YouTube URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _video = null;
      _thumbnailUrls = {};
    });

    try {
      final video = await _youtubeService.getVideoDetails(_urlController.text);
      final thumbnails = {
        'High Quality': video.thumbnailUrl,
      };

      setState(() {
        _video = video;
        _thumbnailUrls = thumbnails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showThumbnailViewer(String quality, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text('Error loading image'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailItem(String quality, String url) {
    return GestureDetector(
      onTap: () => _showThumbnailViewer(quality, url),
      child: Card(
        elevation: 4,
        child: Column(
          children: [
            Expanded(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text('Error loading image'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                quality,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thumbnail Viewer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Enter YouTube URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _fetchVideoData,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('View'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_video != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _video!.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _thumbnailUrls.isEmpty
                  ? const Center(
                      child: Text('No thumbnails available'),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 16 / 10,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _thumbnailUrls.length,
                      itemBuilder: (context, index) {
                        final entry = _thumbnailUrls.entries.elementAt(index);
                        return _buildThumbnailItem(entry.key, entry.value);
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
