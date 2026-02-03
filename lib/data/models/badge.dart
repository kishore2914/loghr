class Badge {
  final String id;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final String? requirement;
  final DateTime? earnedDate;
  final DateTime createdAt;

  Badge({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    this.requirement,
    this.earnedDate,
    required this.createdAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? 'emoji_events',
      color: json['color'] as String? ?? '#FFD700',
      requirement: json['requirement'] as String?,
      earnedDate: json['earned_date'] != null
          ? DateTime.parse(json['earned_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'requirement': requirement,
      'earned_date': earnedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Badge copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? color,
    String? requirement,
    DateTime? earnedDate,
    DateTime? createdAt,
  }) {
    return Badge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      requirement: requirement ?? this.requirement,
      earnedDate: earnedDate ?? this.earnedDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isEarned => earnedDate != null;
}
