class Policy {
  final String id;
  final String? organizationId;
  final String title;
  final String content;
  final DateTime? lastUpdated;
  final String? category;
  final bool isActive;

  Policy({
    required this.id,
    this.organizationId,
    required this.title,
    required this.content,
    this.lastUpdated,
    this.category,
    this.isActive = true,
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String?,
      title: json['heading'] as String? ?? json['title'] as String? ?? 'Untitled Policy',
      content: json['description'] as String? ?? json['content'] as String? ?? '',
      lastUpdated: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : json['created_at'] != null 
              ? DateTime.parse(json['created_at'] as String) 
              : null,
      category: json['category'] as String? ?? 'General',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
