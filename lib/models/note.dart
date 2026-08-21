class Note {
  String id;
  String title;
  String content;
  String date;
  int colorIndex; // 0-5 for 6 label colors
  bool isPinned;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.colorIndex = 0,
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'date': date,
    'colorIndex': colorIndex,
    'isPinned': isPinned,
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    date: json['date'],
    colorIndex: json['colorIndex'] ?? 0,
    isPinned: json['isPinned'] ?? false,
  );

  int get wordCount {
    try {
      // content is JSON — measure script words
      final map = {'script': ''};
      map.addAll({'script': content});
      return content.trim().split(RegExp(r'\s+')).length;
    } catch (_) {
      return 0;
    }
  }
}
