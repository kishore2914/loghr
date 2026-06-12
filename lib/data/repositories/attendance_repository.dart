import 'package:loghr_mobile/data/models/attendance.dart';
import 'package:loghr_mobile/data/services/attendance_service.dart';

class AttendanceRepository {
  final AttendanceService _service;

  AttendanceRepository(this._service);

  Future<Attendance> checkIn({
    required String userId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    return await _service.checkIn(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  Future<Attendance> checkOut({
    required String userId,
    required String attendanceId,
    required double latitude,
    required double longitude,
    required String address,
    String? earlyCheckoutReason,
    bool isAutoCheckout = false,
  }) async {
    return await _service.checkOut(
      userId: userId,
      attendanceId: attendanceId,
      latitude: latitude,
      longitude: longitude,
      address: address,
      earlyCheckoutReason: earlyCheckoutReason,
      isAutoCheckout: isAutoCheckout,
    );
  }

  Future<Attendance?> getTodayAttendance(String userId) async {
    return await _service.getTodayAttendance(userId);
  }

  Future<Attendance?> getIncompleteCheckoutFromPreviousDay(String userId) async {
    return await _service.getIncompleteCheckoutFromPreviousDay(userId);
  }

  Future<List<Attendance>> getHistory(String userId) async {
    return await _service.getHistory(userId);
  }

  Future<bool> requestCalendarStatus({
    required String userId,
    required DateTime date,
    required String status,
  }) async {
    return await _service.requestCalendarStatus(
      userId: userId,
      date: date,
      status: status,
    );
  }

  Future<bool> updateCalendarStatus({
    required String userId,
    required DateTime date,
    required String status,
  }) async {
    return await _service.updateCalendarStatus(
      userId: userId,
      date: date,
      status: status,
    );
  }
}


