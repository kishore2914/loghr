import 'package:loghr_mobile/data/models/attendance.dart';
import 'package:loghr_mobile/config/api_client.dart';

class AttendanceService {
  Future<Attendance?> getIncompleteCheckoutFromPreviousDay(String userId) async {
    try {
      final response = await api.get('/attendance/incomplete');
      if (response == null) return null;
      return Attendance.fromJson(response);
    } catch (e) {
      print('Get incomplete checkout error: $e');
      return null;
    }
  }

  Future<Attendance> checkIn({
    required String userId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      final response = await api.post('/attendance/check-in', {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      });

      return Attendance.fromJson(response);
    } catch (e) {
      print('Check-in error: $e');
      rethrow;
    }
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
    try {
      final response = await api.post('/attendance/check-out', {
        'attendanceId': attendanceId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'earlyCheckoutReason': earlyCheckoutReason,
        'isAutoCheckout': isAutoCheckout,
      });

      return Attendance.fromJson(response);
    } catch (e) {
      print('Check-out error: $e');
      rethrow;
    }
  }

  Future<Attendance?> getTodayAttendance(String userId) async {
    try {
      final response = await api.get('/attendance/today');
      if (response == null) return null;
      return Attendance.fromJson(response);
    } catch (e) {
      print('Get today attendance error: $e');
      return null;
    }
  }

  Future<List<Attendance>> getHistory(String userId) async {
    try {
      final response = await api.get('/attendance/history');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => Attendance.fromJson(json)).toList();
    } catch (e) {
      print('Get attendance history error: $e');
      return [];
    }
  }

  Future<bool> requestCalendarStatus({
    required String userId,
    required DateTime date,
    required String status,
  }) async {
    try {
      final response = await api.post('/attendance/calendar-request', {
        'date': date.toIso8601String(),
        'status': status,
      });
      return response != null && response['success'] == true;
    } catch (e) {
      print('Request calendar status error: $e');
      return false;
    }
  }

  Future<bool> updateCalendarStatus({
    required String userId,
    required DateTime date,
    required String status,
  }) async {
    try {
      final response = await api.post('/attendance/calendar-update', {
        'userId': userId,
        'date': date.toIso8601String(),
        'status': status,
      });
      return response != null && response['success'] == true;
    } catch (e) {
      print('Update calendar status error: $e');
      return false;
    }
  }
}
