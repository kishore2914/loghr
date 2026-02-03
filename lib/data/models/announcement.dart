class Announcement {
  final String id;
  final String? organizationId;
  final String title;
  final String content;
  final String category;
  final String priority;
  final DateTime createdAt;
  final bool isNew;
  final bool isRead;

  Announcement({
    required this.id,
    this.organizationId,
    required this.title,
    required this.content,
    required this.category,
    required this.priority,
    required this.createdAt,
    this.isNew = false,
    this.isRead = false,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String?,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String? ?? 'GENERAL',
      priority: json['priority'] as String? ?? 'NORMAL',
      createdAt: DateTime.parse(json['created_at'] as String),
      // isNew and isRead logic can be handled in service or provider
      isNew: json['is_new'] as bool? ?? false, 
      isRead: json['is_read'] as bool? ?? true,
    );
  }
}

