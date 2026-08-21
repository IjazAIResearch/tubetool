import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tubegrow/models/tag_topic.dart';
// Make sure the TagTopic class is defined in tag_topic.dart and is being exported properly.

// part 'hive_adapters.g.dart';

@HiveType(typeId: 0)
class TagTopicAdapter extends TypeAdapter<TagTopic> {
  @override
  final typeId = 0;

  @override
  TagTopic read(BinaryReader reader) {
    return TagTopic(
      id: reader.read(),
      name: reader.read(),
      tags: List<String>.from(reader.read()),
      createdAt: DateTime.parse(reader.read()),
    );
  }

  @override
  void write(BinaryWriter writer, TagTopic obj) {
    writer.write(obj.id);
    writer.write(obj.name);
    writer.write(obj.tags);
    writer.write(obj.createdAt.toIso8601String());
  }
}

@HiveType(typeId: 1)
class SavedNoteAdapter extends TypeAdapter<SavedNote> {
  @override
  final typeId = 1;

  @override
  SavedNote read(BinaryReader reader) {
    return SavedNote(
      id: reader.read(),
      title: reader.read(),
      content: reader.read(),
      createdAt: DateTime.parse(reader.read()),
      type: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, SavedNote obj) {
    writer.write(obj.id);
    writer.write(obj.title);
    writer.write(obj.content);
    writer.write(obj.createdAt.toIso8601String());
    writer.write(obj.type);
  }
}
