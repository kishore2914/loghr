enum LeaveStatus {
  pending,
  approved,
  rejected,
}

// Model for dynamic leave types from DB
class LeaveTypeData {
  final String id;
  final String name;
  final String code;

  LeaveTypeData({
    required this.id,
    required this.name,
    required this.code,
  });

  factory LeaveTypeData.fromJson(Map<String, dynamic> json) {
    return LeaveTypeData(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
    );
  }
}

class LeaveBalance {
  final String leaveTypeId;
  final String leaveName;
  final String leaveCode; // e.g. CL, SL
  final double total;
  final double used;
  final double available; // Closing balance

  LeaveBalance({
    required this.leaveTypeId,
    required this.leaveName,
    required this.leaveCode,
    required this.total,
    required this.used,
    required this.available,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    // Handle joined leave_types data
    final typeData = json['leave_types'] as Map<String, dynamic>? ?? {};
    final name = typeData['name'] as String? ?? 'Unknown';
    final code = typeData['code'] as String? ?? 'UNK';
    
    // In your schema:
    // opening_balance + accrued = total entitlement?
    // closing_balance = available
    // used = used
    
    final opening = (json['opening_balance'] as num?)?.toDouble() ?? 0.0;
    final accrued = (json['accrued'] as num?)?.toDouble() ?? 0.0;
    final usedVal = (json['used'] as num?)?.toDouble() ?? 0.0;
    final closing = (json['closing_balance'] as num?)?.toDouble() ?? 0.0;
    
    // Fallback logic if total is not explicitly stored
    final totalVal = opening + accrued;

    return LeaveBalance(
      leaveTypeId: json['leave_type_id'] as String,
      leaveName: name,
      leaveCode: code,
      total: totalVal,
      used: usedVal,
      available: closing,
    );
  }
}

class Leave {
  final String id;
  final String userId;
  final String leaveTypeId;
  final String leaveTypeName; // Joined from leave_types
  final String leaveTypeCode; // Joined from leave_types
  final DateTime startDate;
  final DateTime endDate;
  final double days;
  final String reason;
  final String? rejectionReason;
  final String? approvedBy;
  final LeaveStatus status;
  final DateTime createdAt;

  Leave({
    required this.id,
    required this.userId,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.leaveTypeCode,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.reason,
    this.rejectionReason,
    this.approvedBy,
    required this.status,
    required this.createdAt,
  });

  factory Leave.fromJson(Map<String, dynamic> json) {
    final typeData = json['leave_types'] as Map<String, dynamic>? ?? {};
    
    return Leave(
      id: json['id'] as String,
      userId: json['employee_id'] as String, // Schema uses employee_id usually
      leaveTypeId: json['leave_type_id'] as String,
      leaveTypeName: typeData['name'] as String? ?? 'Leave',
      leaveTypeCode: typeData['code'] as String? ?? 'LV',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      days: (json['days'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String? ?? '',
      rejectionReason: json['rejection_reason'] as String?,
      approvedBy: json['approved_by_name'] as String? ?? json['approver_name'] as String?,
      status: LeaveStatus.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == (json['status'] as String? ?? 'pending').toLowerCase(),
        orElse: () => LeaveStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

