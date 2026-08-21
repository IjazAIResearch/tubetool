import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubegrow/services/youtube_service.dart';
import '../constants/app_config.dart';

class KeywordSuggestionScreen extends StatefulWidget {
  const KeywordSuggestionScreen({super.key});

  @override
  State<KeywordSuggestionScreen> createState() =>
      _KeywordSuggestionScreenState();
}

class _KeywordSuggestionScreenState extends State<KeywordSuggestionScreen> {
  final _searchController = TextEditingController();
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  Map<String, List<String>> _suggestions = {
    'Questions': [],
    'How to': [],
    'Reviews': [],
    'Lists': [],
    'Others': [],
  };
  bool _isLoading = false;
  String? _error;
  final String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getKeywordSuggestions() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final suggestions = await _youtubeService.getDetailedKeywordSuggestions(
        _searchController.text,
      );
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildSuggestionList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getKeywordSuggestions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_selectedCategory == 'All') {
      return Expanded(
        child: ListView.builder(
          itemCount: _suggestions.length,
          itemBuilder: (context, index) {
            final category = _suggestions.keys.elementAt(index);
            final suggestions = _suggestions[category]!;
            if (suggestions.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      suggestions.map((suggestion) {
                        return ActionChip(
                          label: Text(suggestion),
                          onPressed: () => _copyToClipboard(suggestion),
                        );
                      }).toList(),
                ),
                const Divider(),
              ],
            );
          },
        ),
      );
    } else {
      final suggestions = _suggestions[_selectedCategory]!;
      if (suggestions.isEmpty) {
        return const Center(
          child: Text('No suggestions found in this category'),
        );
      }

      return Expanded(
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                suggestions.map((suggestion) {
                  return ActionChip(
                    label: Text(suggestion),
                    onPressed: () => _copyToClipboard(suggestion),
                  );
                }).toList(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keyword Suggestions')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter a keyword',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _getKeywordSuggestions,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _getKeywordSuggestions(),
            ),
            const SizedBox(height: 16),
            _buildSuggestionList(),
          ],
        ),
      ),
    );
  }
}
