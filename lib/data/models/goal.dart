enum GoalType {
  personal,
  team,
  department;

  String get displayName {
    switch (this) {
      case GoalType.personal:
        return 'Personal';
      case GoalType.team:
        return 'Team';
      case GoalType.department:
        return 'Department';
    }
  }
}

enum GoalPriority {
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case GoalPriority.low:
        return 'Low';
      case GoalPriority.medium:
        return 'Medium';
      case GoalPriority.high:
        return 'High';
    }
  }
}

enum GoalStatus {
  active,
  completed,
  overdue;

  String get displayName {
    switch (this) {
      case GoalStatus.active:
        return 'Active';
      case GoalStatus.completed:
        return 'Completed';
      case GoalStatus.overdue:
        return 'Overdue';
    }
  }
}

class Goal {
  final String id;
  final String employeeId;
  final String title;
  final String? description;
  final GoalType type;
  final GoalPriority priority;
  final GoalStatus status;
  final int progress; // 0-100
  final DateTime startDate;
  final DateTime dueDate;
  final DateTime? completedDate;
  final int xpReward;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.employeeId,
    required this.title,
    this.description,
    required this.type,
    required this.priority,
    required this.status,
    required this.progress,
    required this.startDate,
    required this.dueDate,
    this.completedDate,
    required this.xpReward,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    // Safely parse required fields with null checks
    final id = json['id'] as String?;
    final employeeId = json['employee_id'] as String?;
    final title = json['title'] as String?;
    final startDateStr = json['start_date'] as String?;
    // Try both 'due_date' and 'end_date' (database uses 'end_date')
    final dueDateStr = json['due_date'] as String? ?? json['end_date'] as String?;
    final createdAtStr = json['created_at'] as String?;
    final updatedAtStr = json['updated_at'] as String?;
    
    // Throw error if required fields are missing
    if (id == null || employeeId == null || title == null || 
        startDateStr == null || dueDateStr == null || 
        createdAtStr == null || updatedAtStr == null) {
      throw Exception('Goal missing required fields: id=$id, employee_id=$employeeId, title=$title, start_date=$startDateStr, due_date/end_date=$dueDateStr, created_at=$createdAtStr, updated_at=$updatedAtStr');
    }
    
    // Get progress from 'progress_percentage' or 'progress' field
    int progressValue = 0;
    if (json['progress_percentage'] != null) {
      progressValue = (json['progress_percentage'] as num).toInt();
    } else if (json['progress'] != null) {
      progressValue = (json['progress'] as num).toInt();
    }
    
    // Parse completed date from 'completion_date' or 'completed_date'
    DateTime? completedDate;
    if (json['completion_date'] != null) {
      final completionStr = json['completion_date'] as String;
      completedDate = _parseDate(completionStr);
    } else if (json['completed_date'] != null) {
      final completedStr = json['completed_date'] as String;
      completedDate = _parseDate(completedStr);
    }
    
    return Goal(
      id: id,
      employeeId: employeeId,
      title: title,
      description: json['description'] as String?,
      type: _parseGoalType(json['type'] as String? ?? json['goal_type_id'] as String?),
      priority: _parseGoalPriority(json['priority'] as String?),
      status: _parseGoalStatus(json['status'] as String?),
      progress: progressValue,
      startDate: _parseDate(startDateStr),
      dueDate: _parseDate(dueDateStr),
      completedDate: completedDate,
      xpReward: json['xp_reward'] as int? ?? 25,
      createdAt: DateTime.parse(createdAtStr),
      updatedAt: DateTime.parse(updatedAtStr),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'title': title,
      'description': description,
      'type': type.name.toUpperCase(),
      'priority': priority.name.toUpperCase(),
      'status': status.name.toUpperCase(),
      'progress': progress,
      'start_date': startDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'completed_date': completedDate?.toIso8601String(),
      'xp_reward': xpReward,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Goal copyWith({
    String? id,
    String? employeeId,
    String? title,
    String? description,
    GoalType? type,
    GoalPriority? priority,
    GoalStatus? status,
    int? progress,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? completedDate,
    int? xpReward,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      completedDate: completedDate ?? this.completedDate,
      xpReward: xpReward ?? this.xpReward,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  // Helper function to parse dates (handles both date-only and datetime formats)
  static DateTime _parseDate(String dateStr) {
    // If it's just a date (YYYY-MM-DD), add time component
    if (dateStr.length == 10 && dateStr.contains('-') && !dateStr.contains('T')) {
      return DateTime.parse('${dateStr}T00:00:00Z');
    }
    return DateTime.parse(dateStr);
  }

  static GoalType _parseGoalType(String? type) {
    if (type == null) return GoalType.personal;
    switch (type.toUpperCase()) {
      case 'TEAM':
        return GoalType.team;
      case 'DEPARTMENT':
        return GoalType.department;
      default:
        return GoalType.personal;
    }
  }

  static GoalPriority _parseGoalPriority(String? priority) {
    if (priority == null) return GoalPriority.medium;
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return GoalPriority.high;
      case 'LOW':
        return GoalPriority.low;
      default:
        return GoalPriority.medium;
    }
  }

  static GoalStatus _parseGoalStatus(String? status) {
    if (status == null) return GoalStatus.active;
    final statusLower = status.toLowerCase().trim();
    final statusUpper = status.toUpperCase().trim();
    
    // Handle both lowercase with underscore and uppercase formats
    switch (statusLower) {
      case 'completed':
      case 'done':
      case 'finished':
        return GoalStatus.completed;
      case 'overdue':
      case 'late':
        return GoalStatus.overdue;
      case 'active':
      case 'in_progress':
      case 'in progress':
      case 'pending':
      case 'ongoing':
      case 'started':
        return GoalStatus.active;
      default:
        // Try uppercase format
        switch (statusUpper) {
          case 'COMPLETED':
          case 'DONE':
          case 'FINISHED':
            return GoalStatus.completed;
          case 'OVERDUE':
          case 'LATE':
            return GoalStatus.overdue;
          case 'ACTIVE':
          case 'IN_PROGRESS':
          case 'IN PROGRESS':
          case 'PENDING':
          case 'ONGOING':
          case 'STARTED':
            return GoalStatus.active;
          default:
            print('Goal: Unknown status "$status", defaulting to active');
            return GoalStatus.active;
        }
    }
  }

  bool get isOverdue {
    return status != GoalStatus.completed && DateTime.now().isAfter(dueDate);
  }

  int get daysRemaining {
    if (status == GoalStatus.completed) return 0;
    return dueDate.difference(DateTime.now()).inDays;
  }
}
