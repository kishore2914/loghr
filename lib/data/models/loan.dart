enum LoanStatus {
  pending,
  approved,
  rejected,
}

class LoanApplication {
  final String id;
  final String employeeId;
  final String userId;
  final double amount;
  final String reason;
  final LoanStatus status;
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final double? grossSalary; // For eligibility checking

  LoanApplication({
    required this.id,
    required this.employeeId,
    required this.userId,
    required this.amount,
    required this.reason,
    required this.status,
    this.rejectionReason,
    this.approvedBy,
    required this.createdAt,
    this.approvedAt,
    this.rejectedAt,
    this.grossSalary,
  });

  factory LoanApplication.fromJson(Map<String, dynamic> json) {
    return LoanApplication(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String? ?? json['user_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['employee_id'] as String? ?? '', // Fallback
      amount: (json['loan_amount'] as num?)?.toDouble() ?? 0.0, // Mapped from loan_amount
      reason: json['notes'] as String? ?? '', // Mapped from notes
      status: LoanStatus.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == 
              (json['status'] as String? ?? 'pending').toLowerCase(),
        orElse: () => LoanStatus.pending,
      ),
      rejectionReason: json['notes'] as String?, // using notes for rejection reason if rejected? Schema doesn't have rejection_reason column distinct from notes usually, but let's check. 
      // ACTUALLY wait, schema DOES NOT have rejection_reason. It has 'notes'.
      // But approved_by is there.
      // let's Assume notes is used for reason.
      approvedBy: json['approved_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      rejectedAt: json['updated_at'] != null && (json['status'] == 'rejected') // Schema has updated_at, separate rejected_at not in CREATE TABLE provided? 
      // Wait, schema provided: approved_at IS there. rejected_at IS NOT.
      // created_at, updated_at ARE there.
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      grossSalary: (json['gross_salary'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'user_id': userId,
      'loan_amount': amount,
      'notes': reason,
      'status': status.toString().split('.').last,
      'approved_by': approvedBy,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      // 'rejected_at' not in schema
    };
  }
}

