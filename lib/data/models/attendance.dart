class Attendance {
  // Helper method to parse DateTime and ensure it's in local timezone
  static DateTime _parseDateTime(String dateTimeString) {
    final parsed = DateTime.parse(dateTimeString);
    // If the parsed time is in UTC, convert to local time
    // If it's already local, return as is
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }
  final String id;
  final String? organizationId;
  final String employeeId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? status;
  final String? workType;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final String? checkInLocation;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String? checkOutLocation;
  final String? earlyCheckoutReason;

  Attendance({
    required this.id,
    this.organizationId,
    required this.employeeId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.status,
    this.workType,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkInLocation,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkOutLocation,
    this.earlyCheckoutReason,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String?,
      employeeId: json['employee_id'] as String,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : (json['check_in_time'] != null
              ? DateTime.parse(json['check_in_time'] as String)
              : DateTime.now()),
      checkInTime: json['check_in_time'] != null
          ? _parseDateTime(json['check_in_time'] as String)
          : null,
      checkOutTime: json['check_out_time'] != null
          ? _parseDateTime(json['check_out_time'] as String)
          : null,
      status: json['status'] as String?,
      workType: json['work_type'] as String?,
      checkInLatitude: json['check_in_latitude'] != null
          ? (json['check_in_latitude'] as num).toDouble()
          : null,
      checkInLongitude: json['check_in_longitude'] != null
          ? (json['check_in_longitude'] as num).toDouble()
          : null,
      checkInLocation: json['check_in_location'] as String?,
      checkOutLatitude: json['check_out_latitude'] != null
          ? (json['check_out_latitude'] as num).toDouble()
          : null,
      checkOutLongitude: json['check_out_longitude'] != null
          ? (json['check_out_longitude'] as num).toDouble()
          : null,
      checkOutLocation: json['check_out_location'] as String?,
      earlyCheckoutReason: (json['early_checkout_reason'] ?? json['notes']) as String?,
    );
  }
  
  // Legacy getter for backward compatibility
  String get userId => employeeId;
  
  // Legacy getters for backward compatibility
  double? get latitude => checkInLatitude;
  double? get longitude => checkInLongitude;
  String? get address => checkInLocation;
  String? get checkInAddress => checkInLocation;
  String? get checkOutAddress => checkOutLocation;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'employee_id': employeeId,
      'date': date.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'status': status,
      'work_type': workType,
      'check_in_latitude': checkInLatitude,
      'check_in_longitude': checkInLongitude,
      'check_in_location': checkInLocation,
      'check_out_latitude': checkOutLatitude,
      'check_out_longitude': checkOutLongitude,
      'check_out_location': checkOutLocation,
      'early_checkout_reason': earlyCheckoutReason,
    };
  }
}

