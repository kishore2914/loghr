enum ReviewStatus {
  pending,
  completed;

  String get displayName {
    switch (this) {
      case ReviewStatus.pending:
        return 'Pending';
      case ReviewStatus.completed:
        return 'Completed';
    }
  }
}

class PerformanceReview {
  final String id;
  final String employeeId;
  final String reviewerId;
  final String period;
  final double rating; // 0.0 - 5.0
  final String? feedback;
  final String? goalId;
  final ReviewStatus status;
  final DateTime? reviewDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional fields for display
  final String? reviewerName;
  final String? goalTitle;

  PerformanceReview({
    required this.id,
    required this.employeeId,
    required this.reviewerId,
    required this.period,
    required this.rating,
    this.feedback,
    this.goalId,
    required this.status,
    this.reviewDate,
    required this.createdAt,
    required this.updatedAt,
    this.reviewerName,
    this.goalTitle,
  });

  factory PerformanceReview.fromJson(Map<String, dynamic> json) {
    // Try multiple possible field names for rating
    double? ratingValue;
    
    // Try 'rating' first
    if (json['rating'] != null) {
      if (json['rating'] is num) {
        ratingValue = (json['rating'] as num).toDouble();
      } else if (json['rating'] is String) {
        ratingValue = double.tryParse(json['rating'] as String);
      }
    }
    
    // Try 'overall_rating' if 'rating' is null
    if (ratingValue == null && json['overall_rating'] != null) {
      if (json['overall_rating'] is num) {
        ratingValue = (json['overall_rating'] as num).toDouble();
      } else if (json['overall_rating'] is String) {
        ratingValue = double.tryParse(json['overall_rating'] as String);
      }
    }
    
    // Default to 0.0 if still null
    ratingValue ??= 0.0;
    
    print('PerformanceReview.fromJson: Parsed rating as $ratingValue from fields: rating=${json['rating']}, overall_rating=${json['overall_rating']}');
    
    return PerformanceReview(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      reviewerId: json['reviewer_id']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      rating: ratingValue,
      feedback: json['feedback'] as String?,
      goalId: json['goal_id'] as String?,
      status: _parseReviewStatus(json['status'] as String?),
      reviewDate: json['review_date'] != null
          ? DateTime.parse(json['review_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      reviewerName: json['reviewer_name'] as String?,
      goalTitle: json['goal_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'reviewer_id': reviewerId,
      'period': period,
      'rating': rating,
      'feedback': feedback,
      'goal_id': goalId,
      'status': status.name.toUpperCase(),
      'review_date': reviewDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PerformanceReview copyWith({
    String? id,
    String? employeeId,
    String? reviewerId,
    String? period,
    double? rating,
    String? feedback,
    String? goalId,
    ReviewStatus? status,
    DateTime? reviewDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reviewerName,
    String? goalTitle,
  }) {
    return PerformanceReview(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      reviewerId: reviewerId ?? this.reviewerId,
      period: period ?? this.period,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      goalId: goalId ?? this.goalId,
      status: status ?? this.status,
      reviewDate: reviewDate ?? this.reviewDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewerName: reviewerName ?? this.reviewerName,
      goalTitle: goalTitle ?? this.goalTitle,
    );
  }

  static ReviewStatus _parseReviewStatus(String? status) {
    if (status == null) return ReviewStatus.pending;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return ReviewStatus.completed;
      default:
        return ReviewStatus.pending;
    }
  }

  int get fullStars => rating.floor();
  bool get hasHalfStar => (rating - fullStars) >= 0.5;
}
