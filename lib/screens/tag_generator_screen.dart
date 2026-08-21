import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tubegrow/services/youtube_service.dart';
import '../constants/app_config.dart';
import '../models/tag_topic.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TagGeneratorScreen extends StatefulWidget {
  const TagGeneratorScreen({super.key});

  @override
  State<TagGeneratorScreen> createState() => _TagGeneratorScreenState();
}

class _TagGeneratorScreenState extends State<TagGeneratorScreen> {
  final _topicController = TextEditingController();
  final _youtubeService = YouTubeService(AppConfig.youtubeApiKey);
  List<String> _generatedTags = [];
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateTags() async {
    if (_topicController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tags = await _youtubeService.suggestTags(_topicController.text);
      setState(() {
        _generatedTags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTagTopic() async {
    if (_generatedTags.isEmpty) return;

    final box = Hive.box('saved_tags');
    final topic = TagTopic(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _topicController.text,
      tags: _generatedTags,
      createdAt: DateTime.now(),
    );
    await box.add(topic);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tags saved successfully')));
    }
  }

  void _copyToClipboard(List<String> tags) {
    final tagString = tags.join(', ');
    Clipboard.setData(ClipboardData(text: tagString));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tags copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag Generator'),
        actions: [
          if (_generatedTags.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveTagTopic,
              tooltip: 'Save tags',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                hintText: 'Enter topic to generate tags',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: _generateTags,
                  tooltip: 'Generate tags',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _generateTags(),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
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
                            onPressed: _generateTags,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _generatedTags.isEmpty
                  ? const Center(
                      child: Text(
                        'Enter a topic to generate tags',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Generated Tags (${_generatedTags.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copyToClipboard(_generatedTags),
                              tooltip: 'Copy all tags',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Card(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _generatedTags.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(_generatedTags[index]),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.content_copy),
                                    onPressed:
                                        () => _copyToClipboard([
                                          _generatedTags[index],
                                        ]),
                                    tooltip: 'Copy tag',
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
