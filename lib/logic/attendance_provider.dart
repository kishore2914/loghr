import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/models/attendance.dart';
import 'package:loghr_mobile/data/repositories/attendance_repository.dart';
import 'package:loghr_mobile/data/services/notification_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _repository;
  final NotificationService _notificationService = NotificationService();
  Attendance? _todayAttendance;
  List<Attendance> _history = [];
  bool _isLoading = false;
  String? _error;
  Attendance? _incompleteCheckoutFromPreviousDay;

  AttendanceProvider(this._repository);

  Attendance? get todayAttendance => _todayAttendance;
  List<Attendance> get history => _history;
  bool get isLoading => _isLoading;
  bool get isCheckedIn => _todayAttendance != null && 
                         _todayAttendance!.checkInTime != null && 
                         _todayAttendance!.checkOutTime == null;
  String? get error => _error;
  Attendance? get incompleteCheckoutFromPreviousDay => _incompleteCheckoutFromPreviousDay;

  Future<void> loadTodayAttendance(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _todayAttendance = await _repository.getTodayAttendance(userId);
      _incompleteCheckoutFromPreviousDay = await _repository.getIncompleteCheckoutFromPreviousDay(userId);
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _history = await _repository.getHistory(userId);
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkIn({
    required String userId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    _error = null;
    try {
      final attendance = await _repository.checkIn(
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      _todayAttendance = attendance;
      
      // Schedule 8-hour notification
      if (attendance.checkInTime != null) {
        await _notificationService.schedule8HourNotification(attendance.checkInTime!);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkOut({
    required String userId,
    required String attendanceId,
    required double latitude,
    required double longitude,
    required String address,
    String? earlyCheckoutReason,
  }) async {
    _error = null;
    try {
      final attendance = await _repository.checkOut(
        userId: userId,
        attendanceId: attendanceId,
        latitude: latitude,
        longitude: longitude,
        address: address,
        earlyCheckoutReason: earlyCheckoutReason,
      );
      _todayAttendance = attendance;
      
      // Cancel notifications on checkout
      await _notificationService.cancelNotifications();
      
      // Reload incomplete checkout status after checkout
      _incompleteCheckoutFromPreviousDay = await _repository.getIncompleteCheckoutFromPreviousDay(userId);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestCalendarStatus({
    required String userId,
    required DateTime date,
    required String status,
  }) async {
    _error = null;
    try {
      final success = await _repository.requestCalendarStatus(
        userId: userId,
        date: date,
        status: status,
      );
      
      if (success) {
        // Reload history to reflect the pending request
        await loadHistory(userId);
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCalendarStatus({
    required String userId,
    required DateTime date,
    required String status,
  }) async {
    _error = null;
    try {
      final success = await _repository.updateCalendarStatus(
        userId: userId,
        date: date,
        status: status,
      );
      
      if (success) {
        // Reload history to reflect the change
        await loadHistory(userId);
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}


