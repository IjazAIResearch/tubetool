import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/tag_topic.dart';

class TagPlannerScreen extends StatelessWidget {
  const TagPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTopicDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box('saved_tags').listenable(),
              builder: (context, box, _) {
                if (box.isEmpty) {
                  return const Center(child: Text('No saved tag topics yet'));
                }

                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final topic = box.getAt(index) as TagTopic;
                    return _buildTopicCard(context, topic);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, TagTopic topic) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(topic.name),
        subtitle: Text('${topic.tags.length} tags'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children:
                  topic.tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      labelStyle: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTopicDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final tagsController = TextEditingController();

    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Topic'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Topic Name',
                    hintText: 'e.g., Gaming Videos',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    hintText: 'gaming, playthrough, lets play',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      tagsController.text.isNotEmpty) {
                    final tags =
                        tagsController.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();

                    final topic = TagTopic.create(nameController.text, tags);
                    Hive.box('saved_tags').add(topic);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }
}
