import 'package:loghr_mobile/config/api_client.dart';
import 'package:loghr_mobile/data/models/leave.dart';

class LeaveService {
  Future<List<LeaveBalance>> getLeaveBalances(String userId) async {
    try {
      final response = await api.get('/leaves/balances');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => LeaveBalance.fromJson(json)).toList();
    } catch (e) {
      print('Get leave balances error: $e');
      return [];
    }
  }

  Future<List<Leave>> getUserLeaves(String userId) async {
    try {
      final response = await api.get('/leaves/applications');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => Leave.fromJson(json)).toList();
    } catch (e) {
      print('Get user leaves error: $e');
      return [];
    }
  }

  Future<List<LeaveTypeData>> getLeaveTypes() async {
    try {
      final response = await api.get('/leaves/types');
      if (response == null) return [];
      
      final list = response as List;
      return list.map((json) => LeaveTypeData.fromJson(json)).toList();
    } catch (e) {
      print('Get leave types error: $e');
      return [];
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
      final response = await api.post('/leaves/apply', {
        'leaveTypeId': leaveTypeId,
        'startDate': startDate.toIso8601String().split('T')[0],
        'endDate': endDate.toIso8601String().split('T')[0],
        'days': days,
        'reason': reason,
        'contactNumber': contactNumber,
      });
      return response != null;
    } catch (e) {
      print('Apply leave error: $e');
      return false;
    }
  }

  Future<bool> updateLeaveStatus(String leaveId, String status) async {
    try {
      final endpoint = status.toLowerCase() == 'approved' ? 'approve' : 'reject';
      final response = await api.post('/leaves/$leaveId/$endpoint', {});
      return response != null;
    } catch (e) {
      print('Update leave status error: $e');
      return false;
    }
  }
}
