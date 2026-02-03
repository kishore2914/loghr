import 'package:loghr_mobile/data/models/leave.dart';
import 'package:loghr_mobile/data/services/leave_service.dart';

class LeaveRepository {
  final LeaveService _service;

  LeaveRepository(this._service);

  Future<List<LeaveBalance>> getLeaveBalances(String userId) async {
    return await _service.getLeaveBalances(userId);
  }

  Future<List<Leave>> getUserLeaves(String userId) async {
    return await _service.getUserLeaves(userId);
  }

  Future<List<LeaveTypeData>> getLeaveTypes() async {
    return await _service.getLeaveTypes();
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
    return await _service.applyLeave(
      userId: userId,
      leaveTypeId: leaveTypeId,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      days: days,
      contactNumber: contactNumber,
    );
  }
}


