import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

//part 'saved_note.g.dart';

@HiveType(typeId: 4)
class SavedNote extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final String type; // 'title', 'description', 'tags', 'comment'

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String? sourceVideoId;

  @HiveField(6)
  final String? sourceVideoTitle;

  SavedNote({
    String? id,
    required this.title,
    required this.content,
    required this.type,
    DateTime? createdAt,
    this.sourceVideoId,
    this.sourceVideoTitle,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  factory SavedNote.create(String title, String content, String type) {
    return SavedNote(title: title, content: content, type: type);
  }

  SavedNote copyWith({
    String? title,
    String? content,
    String? type,
    String? sourceVideoId,
    String? sourceVideoTitle,
  }) {
    return SavedNote(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt,
      sourceVideoId: sourceVideoId ?? this.sourceVideoId,
      sourceVideoTitle: sourceVideoTitle ?? this.sourceVideoTitle,
    );
  }
}
