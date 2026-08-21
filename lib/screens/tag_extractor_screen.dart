import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_config.dart';
import '../models/tag_topic.dart';
import '../models/video.dart';
import '../services/youtube_service.dart';
import '../widgets/tag_list.dart';
import '../widgets/tag_category_chip.dart';
import '../services/review_service.dart';

class TagExtractorScreen extends StatefulWidget {
  const TagExtractorScreen({super.key});

  @override
  State<TagExtractorScreen> createState() => _TagExtractorScreenState();
}

class _TagExtractorScreenState extends State<TagExtractorScreen> {
  final _urlController = TextEditingController();
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  Video? _video;
  bool _isLoading = false;
  String? _error;
  List<String> _suggestedTags = [];
  final Set<String> _selectedTags = {};
  final TextEditingController _noteController = TextEditingController();
  final Map<String, List<String>> _categorizedTags = {
    'Topic': [],
    'Technical': [],
    'Descriptive': [],
    'Custom': [],
  };
  String _selectedCategory = 'All';
  String _tagFilter = '';
  String _suggestKeyword = '';
  bool _isLoadingSuggestions = false;
  bool _showAdvancedSuggestions = false;
  final Set<String> _selectedSuggestedTags = {};

  @override
  void dispose() {
    _urlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _categorizeTags() {
    if (_video == null) return;
    _categorizedTags.forEach((key, value) => value.clear());

    for (var tag in _video!.tags) {
      if (tag.contains(RegExp(r'tutorial|how to|guide'))) {
        _categorizedTags['Technical']!.add(tag);
      } else if (tag.contains(RegExp(r'best|top|review|amazing'))) {
        _categorizedTags['Descriptive']!.add(tag);
      } else {
        _categorizedTags['Topic']!.add(tag);
      }
    }
  }

  Future<void> _searchSuggestions(String keyword) async {
    if (keyword.isEmpty) return;

    setState(() {
      _isLoadingSuggestions = true;
      _suggestedTags = [];
      _selectedSuggestedTags.clear();
    });

    try {
      final suggestions = await _youtubeService.suggestTags(keyword);
      setState(() {
        _suggestedTags = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingSuggestions = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load suggestions: $e')));
    }
  }

  void _toggleSuggestedTag(String tag) {
    setState(() {
      if (_selectedSuggestedTags.contains(tag)) {
        _selectedSuggestedTags.remove(tag);
      } else {
        _selectedSuggestedTags.add(tag);
      }
    });
  }

  void _addAllSuggestedTags() {
    setState(() {
      _selectedTags.addAll(_suggestedTags);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${_suggestedTags.length} tags')),
    );
  }

  void _addSelectedSuggestedTags() {
    setState(() {
      _selectedTags.addAll(_selectedSuggestedTags);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${_selectedSuggestedTags.length} tags')),
    );
  }

  void _copySuggestedTags(List<String> tags) {
    final content = tags.join(', ');
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${tags.length} tags to clipboard')),
    );
  }

  Future<void> _extractTags() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _suggestedTags = [];
      _selectedTags.clear();
      _selectedSuggestedTags.clear();
    });

    try {
      final url = _urlController.text;
      final videoId = _extractVideoId(url);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }
      final video = await _youtubeService.getVideoDetails(videoId);
      final suggestions = await _youtubeService.suggestTags(
        video.title.split(' ')[0],
      );
      setState(() {
        _video = video;
        _suggestedTags = suggestions;
        _isLoading = false;
      });
      _categorizeTags();

      // Record feature use and try to show review at this success moment
      await ReviewService.instance.recordFeatureUse('tag_extractor');
      ReviewService.instance.tryShowReview();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String? _extractVideoId(String url) {
    RegExp regExp = RegExp(
      r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*).*',
    );
    Match? match = regExp.firstMatch(url);
    return match?[7];
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _exportAllData() async {
    if (_video == null) return;

    final exportData = {
      'title': _video!.title,
      'description': _video!.description,
      'tags': _selectedTags.isEmpty ? _video!.tags : _selectedTags.toList(),
      'categorized_tags': _categorizedTags,
      'notes': _noteController.text,
      'channel': _video!.channelTitle,
      'stats': {'views': _video!.viewCount, 'likes': _video!.likeCount},
      'export_date': DateTime.now().toIso8601String(),
    };

    final content = const JsonEncoder.withIndent('  ').convert(exportData);
    await Clipboard.setData(ClipboardData(text: content));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All data exported to clipboard as JSON')),
    );
  }

  Future<void> _saveToTopic() async {
    if (_selectedTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one tag')),
      );
      return;
    }

    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NewTopicDialog(),
    );

    if (name != null && name.isNotEmpty) {
      final topic = TagTopic.create(name, _selectedTags.toList());
      await Hive.box('saved_tags').add(topic);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${_selectedTags.length} tags to "$name"'),
          ),
        );
      }
    }
  }

  void _copyVideoInfo(String type) {
    if (_video == null) return;

    String content;
    String message;

    switch (type) {
      case 'title':
        content = _video!.title;
        message = 'Title copied to clipboard';
        break;
      case 'description':
        content = _video!.description;
        message = 'Description copied to clipboard';
        break;
      case 'tags':
        content =
            _selectedTags.isEmpty
                ? _video!.tags.join(', ')
                : _selectedTags.join(', ');
        message = 'Tags copied to clipboard';
        break;
      default:
        return;
    }

    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveNote(String type) async {
    if (_video == null) return;

    String content;
    String title;

    switch (type) {
      case 'title':
        content = _video!.title;
        title = 'Video Title';
        break;
      case 'description':
        content = _video!.description;
        title = 'Video Description';
        break;
      case 'tags':
        content =
            _selectedTags.isEmpty
                ? _video!.tags.join(', ')
                : _selectedTags.join(', ');
        title = 'Video Tags';
        break;
      default:
        return;
    }

    final note = SavedNote.create(title, content, type);
    await Hive.box('saved_notes').put(note.id, note);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved to notes')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Tags'),
        actions: [
          if (_video != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: _saveNote,
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'title',
                      child: Text('Save Title to Notes'),
                    ),
                    const PopupMenuItem(
                      value: 'description',
                      child: Text('Save Description to Notes'),
                    ),
                    const PopupMenuItem(
                      value: 'tags',
                      child: Text('Save Tags to Notes'),
                    ),
                  ],
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'YouTube Video URL',
                  hintText: 'https://youtube.com/watch?v=...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _urlController.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _extractTags,
                icon:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.search),
                label: Text(_isLoading ? 'Extracting...' : 'Extract Tags'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_video != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    title: Text(
                      _video!.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(_video!.channelTitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyVideoInfo('title'),
                          tooltip: 'Copy Title',
                        ),
                        IconButton(
                          icon: const Icon(Icons.description),
                          onPressed: () => _copyVideoInfo('description'),
                          tooltip: 'Copy Description',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Video Tags',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    if (_selectedTags.isNotEmpty) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Save Selected'),
                        onPressed: _saveToTopic,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Selected'),
                        onPressed: () => _copyVideoInfo('tags'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Filter tags...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged:
                            (value) => setState(() => _tagFilter = value),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort),
                      tooltip: 'Sort tags',
                      itemBuilder:
                          (context) => [
                            const PopupMenuItem(
                              value: 'az',
                              child: Text('A-Z'),
                            ),
                            const PopupMenuItem(
                              value: 'length',
                              child: Text('By Length'),
                            ),
                          ],
                      onSelected: (value) {
                        setState(() {
                          if (value == 'az') {
                            _video!.tags.sort();
                          } else if (value == 'length') {
                            _video!.tags.sort(
                              (a, b) => a.length.compareTo(b.length),
                            );
                          }
                          _categorizeTags();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      TagCategoryChip(
                        category: 'All',
                        isSelected: _selectedCategory == 'All',
                        onTap: () => setState(() => _selectedCategory = 'All'),
                      ),
                      const SizedBox(width: 8),
                      for (final category in _categorizedTags.keys)
                        if (_categorizedTags[category]!.isNotEmpty) ...[
                          TagCategoryChip(
                            category: category,
                            isSelected: _selectedCategory == category,
                            onTap:
                                () => setState(
                                  () => _selectedCategory = category,
                                ),
                          ),
                          const SizedBox(width: 8),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: TagList(
                    tags:
                        _selectedCategory == 'All'
                            ? _video!.tags
                                .where(
                                  (tag) => tag.toLowerCase().contains(
                                    _tagFilter.toLowerCase(),
                                  ),
                                )
                                .toList()
                            : _categorizedTags[_selectedCategory]!
                                .where(
                                  (tag) => tag.toLowerCase().contains(
                                    _tagFilter.toLowerCase(),
                                  ),
                                )
                                .toList(),
                    selectedTags: _selectedTags,
                    onTagTap: _toggleTag,
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Text(
                      'Keyword Suggestions',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _showAdvancedSuggestions
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onPressed:
                          () => setState(
                            () =>
                                _showAdvancedSuggestions =
                                    !_showAdvancedSuggestions,
                          ),
                      tooltip: 'Toggle advanced suggestions',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Enter keyword for suggestions...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              _isLoadingSuggestions
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                  : null,
                        ),
                        onChanged: (value) => _suggestKeyword = value,
                        onSubmitted: _searchSuggestions,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => _searchSuggestions(_suggestKeyword),
                      tooltip: 'Search suggestions',
                    ),
                  ],
                ),
                if (_suggestedTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  if (_showAdvancedSuggestions) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.add, size: 16),
                                label: const Text('Add All'),
                                onPressed: _addAllSuggestedTags,
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy All'),
                                onPressed:
                                    () => _copySuggestedTags(_suggestedTags),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    height: 100,
                    child: TagList(
                      tags: _suggestedTags,
                      selectedTags: _selectedSuggestedTags,
                      onTagTap: _toggleSuggestedTag,
                    ),
                  ),
                  if (_selectedSuggestedTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Selected'),
                          onPressed: _addSelectedSuggestedTags,
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Selected'),
                          onPressed:
                              () => _copySuggestedTags(
                                _selectedSuggestedTags.toList(),
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
                const Divider(),
                Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add notes about this video...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export All'),
                      onPressed: () => _exportAllData(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTopicDialog extends StatelessWidget {
  final _controller = TextEditingController();

  _NewTopicDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Topic'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Topic Name',
          hintText: 'e.g., Gaming Videos',
        ),
        autofocus: true,
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            Navigator.pop(context, value);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final value = _controller.text;
            if (value.isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
