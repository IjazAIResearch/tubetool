import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class UploadChecklistScreen extends StatefulWidget {
  const UploadChecklistScreen({super.key});

  @override
  State<UploadChecklistScreen> createState() => _UploadChecklistScreenState();
}

class _UploadChecklistScreenState extends State<UploadChecklistScreen> {
  late Box _checklistBox;
  bool _isInitialized = false;

  final List<Map<String, dynamic>> _checklistItems = [
    {
      'key': 'title',
      'title': 'Title Optimized',
      'subtitle': 'Keep between 50-60 characters with keywords',
      'icon': Icons.title,
      'tip':
          'Use power words like "Ultimate", "Best", "How To" and include your main keyword. Example: "How To Grow YouTube Channel FAST in 2025 (Step by Step)"',
    },
    {
      'key': 'description',
      'title': 'Description Written',
      'subtitle': 'Minimum 200 words with keywords & links',
      'icon': Icons.description,
      'tip':
          'First 2 lines are most important (shown in search). Include: main keyword in first sentence, relevant links, social links, timestamps, and a call to action.',
    },
    {
      'key': 'tags',
      'title': 'Tags Added',
      'subtitle': 'At least 10-15 relevant tags',
      'icon': Icons.local_offer,
      'tip':
          'Mix broad and specific tags. Start with your exact title, then add variations. Include: main keyword, related keywords, channel name, and category terms.',
    },
    {
      'key': 'thumbnail',
      'title': 'Custom Thumbnail',
      'subtitle': 'High quality, 1280×720 min resolution',
      'icon': Icons.image,
      'tip':
          'Use bright colors, big text (3-5 words max), expressive face, and contrast. Avoid clutter. Test how it looks at small size (search results).',
    },
    {
      'key': 'endscreen',
      'title': 'End Screen Added',
      'subtitle': 'Subscribe button & video recommendation',
      'icon': Icons.screen_share,
      'tip':
          'Add end screen in last 20 seconds. Include: subscribe button, best video suggestion, and playlist link. Keep the layout clean.',
    },
    {
      'key': 'cards',
      'title': 'Info Cards Added',
      'subtitle': 'Link to related videos or playlists',
      'icon': Icons.web_stories,
      'tip':
          'Add cards at moments where viewers might leave. Link to your most relevant video/playlist. Max 5 cards per video. Time them with your narration.',
    },
    {
      'key': 'hashtags',
      'title': 'Hashtags Added',
      'subtitle': 'Add 3 hashtags in description',
      'icon': Icons.tag,
      'tip':
          'YouTube shows max 3 hashtags above the title. Use format: #MainKeyword #NicheKeyword #BrandName. Place them at the very end of description.',
    },
    {
      'key': 'comment',
      'title': 'Pinned Comment',
      'subtitle': 'Pin a comment with CTA or link',
      'icon': Icons.push_pin,
      'tip':
          'Pin a comment with: a question to encourage replies, a link to a related resource, or a short summary of the video. This boosts engagement metrics.',
    },
    {
      'key': 'playlist',
      'title': 'Added to Playlist',
      'subtitle': 'Organize video in relevant playlist',
      'icon': Icons.playlist_add,
      'tip':
          'Add every video to at least one playlist. Playlists increase session watch time. Create topic-based playlists, not date-based ones.',
    },
    {
      'key': 'premiere',
      'title': 'Schedule/Premiere Set',
      'subtitle': 'Schedule upload for optimal time',
      'icon': Icons.schedule,
      'tip':
          'Schedule for when your audience is most active. Check YouTube Analytics → Audience tab for the best time. Premieres can boost initial engagement.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    _checklistBox = await Hive.openBox('upload_checklist');
    setState(() => _isInitialized = true);
  }

  bool _isChecked(String key) {
    return _checklistBox.get(key, defaultValue: false);
  }

  void _toggleItem(String key) {
    final current = _isChecked(key);
    _checklistBox.put(key, !current);
    setState(() {});
  }

  int get _checkedCount =>
      _checklistItems.where((item) => _isChecked(item['key'])).length;

  double get _progress => _checkedCount / _checklistItems.length;

  void _resetChecklist() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Checklist'),
        content: const Text('Reset all items for a new upload?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              for (final item in _checklistItems) {
                _checklistBox.put(item['key'], false);
              }
              setState(() {});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checklist reset! Ready for your next upload 🚀')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTip(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item['icon'] as IconData,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '💡 Pro Tip',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber[700],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item['tip'] as String,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload Checklist')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset checklist',
            onPressed: _resetChecklist,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_checkedCount/${_checklistItems.length} completed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${(_progress * 100).round()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _progress == 1.0 ? Colors.green : colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 10,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: _progress == 1.0 ? Colors.green : colorScheme.primary,
                  ),
                ),
                if (_progress == 1.0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Ready to publish! 🎬',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Checklist items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _checklistItems.length,
              itemBuilder: (context, index) {
                final item = _checklistItems[index];
                final checked = _isChecked(item['key']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _toggleItem(item['key']),
                    onLongPress: () => _showTip(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: checked,
                            onChanged: (_) => _toggleItem(item['key']),
                            activeColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Icon(
                            item['icon'] as IconData,
                            color: checked
                                ? Colors.green
                                : colorScheme.onSurface.withOpacity(0.5),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    decoration:
                                        checked ? TextDecoration.lineThrough : null,
                                    color: checked
                                        ? colorScheme.onSurface.withOpacity(0.5)
                                        : null,
                                  ),
                                ),
                                Text(
                                  item['subtitle'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.lightbulb_outline,
                              size: 20,
                              color: Colors.amber[700],
                            ),
                            tooltip: 'Show tip',
                            onPressed: () => _showTip(item),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
