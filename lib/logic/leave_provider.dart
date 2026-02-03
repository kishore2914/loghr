import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/models/leave.dart';
import 'package:loghr_mobile/data/repositories/leave_repository.dart';

class LeaveProvider extends ChangeNotifier {
  final LeaveRepository _repository;
  List<LeaveBalance> _leaveBalances = [];
  List<Leave> _userLeaves = [];
  List<LeaveTypeData> _leaveTypes = [];
  bool _isLoading = false;

  LeaveProvider(this._repository);

  List<LeaveBalance> get leaveBalances => _leaveBalances;
  List<Leave> get userLeaves => _userLeaves;
  List<LeaveTypeData> get leaveTypes => _leaveTypes;
  bool get isLoading => _isLoading;

  Future<void> loadData(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadLeaveBalances(userId),
        loadUserLeaves(userId),
        loadLeaveTypes(),
      ]);
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLeaveBalances(String userId) async {
    try {
      _leaveBalances = await _repository.getLeaveBalances(userId);
      notifyListeners();
    } catch (e) {
      print('Provider load balances error: $e');
    }
  }

  Future<void> loadUserLeaves(String userId) async {
    try {
      _userLeaves = await _repository.getUserLeaves(userId);
      notifyListeners();
    } catch (e) {
      print('Provider load user leaves error: $e');
    }
  }

  Future<void> loadLeaveTypes() async {
    try {
      _leaveTypes = await _repository.getLeaveTypes();
      notifyListeners();
    } catch (e) {
      print('Provider load leave types error: $e');
    }
  }

  Future<bool> applyLeave({
    required String userId,
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required double days,
    String? contactNumber,
  }) async {
    try {
      final success = await _repository.applyLeave(
        userId: userId,
        leaveTypeId: leaveTypeId,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        days: days,
        contactNumber: contactNumber,
      );
      
      if (success) {
        await loadUserLeaves(userId);
        await loadLeaveBalances(userId); // Balances might update
      }
      return success;
    } catch (e) {
      return false;
    }
  }
}


