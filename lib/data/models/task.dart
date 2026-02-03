class Task {
  final String id;
  final String organizationId;
  final String title;
  final String? description;
  final String? assignedTo;
  final String? assignedBy;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String priority; // low, medium, high, urgent
  final String status; // pending, in_progress, completed, cancelled, on_hold
  final int progressPercentage;
  final String? parentTaskId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? estimatedHours;
  final String? githubRepo;
  final int? githubIssueNumber;
  final int? githubPrNumber;
  final String taskType; // feature, bug, enhancement, etc.
  final int? xpReward; // XP reward for completing the task
  
  // Joined fields
  final String? assigneeName;

  Task({
    required this.id,
    required this.organizationId,
    required this.title,
    this.description,
    this.assignedTo,
    this.assignedBy,
    this.startDate,
    this.dueDate,
    this.completedAt,
    required this.priority,
    required this.status,
    required this.progressPercentage,
    this.parentTaskId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.estimatedHours,
    this.githubRepo,
    this.githubIssueNumber,
    this.githubPrNumber,
    required this.taskType,
    this.xpReward,
    this.assigneeName,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      assignedTo: json['assigned_to'] as String?,
      assignedBy: json['assigned_by'] as String?,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      priority: json['priority'] as String? ?? 'medium',
      status: json['status'] as String? ?? 'pending',
      progressPercentage: json['progress_percentage'] as int? ?? 0,
      parentTaskId: json['parent_task_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      estimatedHours: json['estimated_hours'] != null 
          ? (json['estimated_hours'] as num).toDouble() 
          : null,
      githubRepo: json['github_repo'] as String?,
      githubIssueNumber: json['github_issue_number'] as int?,
      githubPrNumber: json['github_pr_number'] as int?,
      taskType: json['task_type'] as String? ?? 'feature',
      xpReward: json['xp_reward'] as int?,
      assigneeName: json['assignee_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'assigned_by': assignedBy,
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'priority': priority,
      'status': status,
      'progress_percentage': progressPercentage,
      'parent_task_id': parentTaskId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'estimated_hours': estimatedHours,
      'github_repo': githubRepo,
      'github_issue_number': githubIssueNumber,
      'github_pr_number': githubPrNumber,
      'task_type': taskType,
      'xp_reward': xpReward,
    };
  }
}
