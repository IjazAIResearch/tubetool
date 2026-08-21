import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class TagTopic {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<String> tags;

  @HiveField(3)
  final DateTime createdAt;

  TagTopic({
    required this.id,
    required this.name,
    required this.tags,
    required this.createdAt,
  });

  factory TagTopic.create(String name, List<String> tags) {
    return TagTopic(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      tags: tags,
      createdAt: DateTime.now(),
    );
  }
}

@HiveType(typeId: 1)
class SavedNote {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String type; // 'title', 'description', 'comment', 'custom'

  SavedNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.type,
  });

  factory SavedNote.create(String title, String content, String type) {
    return SavedNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
      type: type,
    );
  }
}
