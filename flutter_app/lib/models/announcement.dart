class Announcement {
  final int id;
  final String title;
  final String message;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'No Title',
      message: json['message'] ?? (json['content'] ?? 'No Message'), // Fallback for legacy
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : (json['published_at'] != null ? DateTime.parse(json['published_at']) : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}



