class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime date;
  final bool isRead;
  final String? relatedId; // ID of related entity (leave_id, task_id, announcement_id, etc.)

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.date,
    this.isRead = false,
    this.relatedId,
  });

  // Create from JSON (Supabase response)
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      date: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      relatedId: json['related_id'] as String?,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'created_at': date.toIso8601String(),
      'is_read': isRead,
      'related_id': relatedId,
    };
  }

  // Copy with method for updates
  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    DateTime? date,
    bool? isRead,
    String? relatedId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId ?? this.relatedId,
    );
  }
}

