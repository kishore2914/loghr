import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/models/attendance.dart';
import 'package:loghr_mobile/data/repositories/attendance_repository.dart';
import 'package:loghr_mobile/data/services/notification_service.dart';
import 'package:loghr_mobile/config/supabase_config.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _repository;
  final NotificationService _notificationService = NotificationService();
  Attendance? _todayAttendance;
  List<Attendance> _history = [];
  bool _isLoading = false;
  String? _error;
  Attendance? _incompleteCheckoutFromPreviousDay;
  Timer? _autoCheckoutTimer;
  Timer? _eightHourNotifyTimer;
  bool _isOvertimeActive = false;

  AttendanceProvider(this._repository);

  Attendance? get todayAttendance => _todayAttendance;
  List<Attendance> get history => _history;
  bool get isLoading => _isLoading;
  bool get isCheckedIn => _todayAttendance != null && 
                         _todayAttendance!.checkInTime != null && 
                         _todayAttendance!.checkOutTime == null;
  String? get error => _error;
  Attendance? get incompleteCheckoutFromPreviousDay => _incompleteCheckoutFromPreviousDay;
  bool get isOvertimeActive => _isOvertimeActive;

  /// Returns true when the employee is checked in and has worked >= 8 hours
  bool get hasCompletedEightHours {
    if (_todayAttendance == null || _todayAttendance!.checkInTime == null || _todayAttendance!.checkOutTime != null) {
      return false;
    }
    return DateTime.now().difference(_todayAttendance!.checkInTime!).inHours >= 8;
  }

  Future<void> loadTodayAttendance(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _todayAttendance = await _repository.getTodayAttendance(userId);
      _incompleteCheckoutFromPreviousDay = await _repository.getIncompleteCheckoutFromPreviousDay(userId);
      
      // Check for auto-checkout on load
      if (_todayAttendance != null && 
          _todayAttendance!.checkInTime != null && 
          _todayAttendance!.checkOutTime == null) {
        _handleAutoCheckoutLogic(userId, _todayAttendance!);
      }
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
        _handleAutoCheckoutLogic(userId, attendance);
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
    bool isAutoCheckout = false,
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
        isAutoCheckout: isAutoCheckout,
      );
      _todayAttendance = attendance;
      
      // Cancel notifications and timer on checkout
      await _notificationService.cancelNotifications();
      _cancelAutoCheckoutTimer();
      _isOvertimeActive = false;
      
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

  /// Activates overtime mode — the employee has chosen to keep working past 8 hours
  void activateOvertime() {
    _isOvertimeActive = true;
    notifyListeners();
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

  void _handleAutoCheckoutLogic(String userId, Attendance attendance) {
    _cancelAutoCheckoutTimer();
    
    final checkIn = attendance.checkInTime!;
    final now = DateTime.now();
    final difference = now.difference(checkIn);
    final eightHours = const Duration(hours: 8);
    final twelveHours = const Duration(hours: 12);

    if (difference >= twelveHours) {
      // Already passed 12 hours - Auto Checkout Immediately
      print('AttendanceProvider: ⏳ 12 hours passed. Triggering immediate auto-checkout.');
      _performAutoCheckout(userId, attendance);
    } else {
      // Schedule 12-hour hard auto-checkout timer
      final remainingToTwelve = twelveHours - difference;
      print('AttendanceProvider: ⏳ Scheduling auto-checkout in ${remainingToTwelve.inMinutes} minutes');
      _autoCheckoutTimer = Timer(remainingToTwelve, () {
        _performAutoCheckout(userId, attendance);
      });

      // Schedule 8-hour UI notification (to reveal overtime button)
      if (difference >= eightHours) {
        // Already past 8 hours — just notify listeners so UI shows the button
        print('AttendanceProvider: ⏳ Already past 8 hours. Overtime button should be visible.');
        notifyListeners();
      } else {
        final remainingToEight = eightHours - difference;
        print('AttendanceProvider: ⏳ Scheduling 8-hour notify in ${remainingToEight.inMinutes} minutes');
        _eightHourNotifyTimer = Timer(remainingToEight, () {
          // Fire notifyListeners so the UI rebuilds and shows the overtime button
          print('AttendanceProvider: ⏳ 8 hours completed. Showing overtime button.');
          notifyListeners();
        });
      }
    }
  }

  void _cancelAutoCheckoutTimer() {
    _autoCheckoutTimer?.cancel();
    _autoCheckoutTimer = null;
    _eightHourNotifyTimer?.cancel();
    _eightHourNotifyTimer = null;
  }

  Future<void> _performAutoCheckout(String userId, Attendance attendance) async {
    // Perform auto-check out with system values.
    // Pass isAutoCheckout: true so the service preserves the check-in work_type
    // instead of re-evaluating GPS with dummy 0,0 coordinates.
    final success = await checkOut(
      userId: userId,
      attendanceId: attendance.id,
      latitude: 0.0,
      longitude: 0.0,
      address: "Auto-Checkout System (12 Hours Completed)",
      earlyCheckoutReason: null, // Set to null for 12-hour auto-checkout
      isAutoCheckout: true,
    );

    if (success) {
      // Notify user locally
      _notificationService.showLocalPopup(
        id: 888, // Unique ID for auto-checkout
        title: "Auto-Checkout Successful",
        body: "You have been automatically checked out after 12 hours (forgot to check out).",
        payload: "auto_checkout",
      );

      // Notify admins in the same organization via Supabase notifications table
      try {
        // Look up employee name
        final profile = await supabase
            .from('user_profiles')
            .select('full_name, employee_id')
            .eq('user_id', userId)
            .maybeSingle();
        final employeeName = profile?['full_name'] as String? ?? 'An employee';
        final employeeId = profile?['employee_id'] as String? ?? userId;

        await _notificationService.createAutoCheckoutAdminNotification(
          employeeId: employeeId,
          employeeName: employeeName,
        );
      } catch (e) {
        print('AttendanceProvider: Error sending admin auto-checkout notification: $e');
      }
    }
  }
  
  @override
  void dispose() {
    _cancelAutoCheckoutTimer();
    _isOvertimeActive = false;
    super.dispose();
  }
}


