import 'package:intl/intl.dart';
import 'package:loghr_mobile/data/models/leave.dart';
import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/data/services/loyalty_service.dart';

class LeaveService {
  // Helper to get employee_id
  Future<String?> _getEmployeeId(String userId) async {
    try {
      final profileData = await supabase
          .from('user_profiles')
          .select('employee_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (profileData != null && profileData['employee_id'] != null) {
        return profileData['employee_id'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<LeaveBalance>> getLeaveBalances(String userId) async {
    try {
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) return [];

      // Fetch balances with joined leave type details
      final data = await supabase
          .from('leave_balances')
          .select('*, leave_types(name, code)')
          .eq('employee_id', employeeId);

      return (data as List).map((json) => LeaveBalance.fromJson(json)).toList();
    } catch (e) {
      print('Get leave balances error: $e');
      return [];
    }
  }

  Future<List<Leave>> getUserLeaves(String userId) async {
    try {
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) return [];

      // Fetch applications with joined leave type details
      final data = await supabase
          .from('leave_applications')
          .select('*, leave_types(name, code)')
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);

      return (data as List).map((json) => Leave.fromJson(json)).toList();
    } catch (e) {
      print('Get user leaves error: $e');
      return [];
    }
  }

  // Fetch all available leave types for dropdown
  Future<List<LeaveTypeData>> getLeaveTypes() async {
    try {
      final data = await supabase
          .from('leave_types')
          .select('id, name, code')
          .eq('is_active', true);
      
      return (data as List).map((json) => LeaveTypeData.fromJson(json)).toList();
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
      final employeeId = await _getEmployeeId(userId);
      if (employeeId == null) throw Exception('Employee ID not found');

      final now = DateTime.now();

      final insertData = <String, dynamic>{
        'employee_id': employeeId,
        'leave_type_id': leaveTypeId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'days': days,
        'reason': reason,
        'status': 'pending',
        'created_at': now.toIso8601String(),
        'organization_id': (await _getOrgId(employeeId)), // Helper to get org ID
      };
      
      // Add contact number if provided (try different possible column names)
      if (contactNumber != null && contactNumber.isNotEmpty) {
        insertData['contact_number'] = contactNumber;
        insertData['contact_phone'] = contactNumber; // Try both column names
        insertData['phone_during_leave'] = contactNumber;
      }

      await supabase.from('leave_applications').insert(insertData);

      return true;
    } catch (e) {
      print('Apply leave error: $e');
      return false;
    }
  }

  Future<String?> _getOrgId(String employeeId) async {
    // Attempt to get org id from employee record if needed by RLS
    try {
        final data = await supabase
            .from('employees') // or user_profiles depending on schema
            .select('organization_id')
            .eq('id', employeeId)
            .maybeSingle();
        return data?['organization_id'] as String?;
    } catch (e) {
        return null;
    }
  }
  Future<bool> updateLeaveStatus(String leaveId, String status) async {
    try {
      // Get leave application details
      final leaveData = await supabase
          .from('leave_applications')
          .select('''
            *,
            leave_types(code, name)
          ''')
          .eq('id', leaveId)
          .maybeSingle();

      if (leaveData == null) return false;

      // Update leave status
      await supabase
          .from('leave_applications')
          .update({'status': status})
          .eq('id', leaveId);

      // If approved, sync to attendance calendar
      if (status.toLowerCase() == 'approved') {
        await _syncApprovedLeaveToCalendar(leaveData);
        
        // Award loyalty points for approved leave/correct records
        try {
          final employeeId = leaveData['employee_id'] as String?;
          if (employeeId != null) {
            final typeData = leaveData['leave_types'] as Map<String, dynamic>? ?? {};
            final leaveTypeName = typeData['name'] as String? ?? 'Leave';
            await LoyaltyService().awardPoints(
              employeeId: employeeId,
              points: 50,
              type: 'leave_record',
              description: 'Award for approved leave: $leaveTypeName',
              referenceId: leaveId,
            );
          }
        } catch (e) {
          print('Error awarding points for leave record: $e');
        }
      } else if (status.toLowerCase() == 'rejected') {
        // Remove calendar entries for rejected leave
        await _removeLeaveFromCalendar(leaveData);
      }

      return true;
    } catch (e) {
      print('Update leave status error: $e');
      return false;
    }
  }

  // Sync approved leave to attendance calendar
  Future<void> _syncApprovedLeaveToCalendar(Map<String, dynamic> leaveData) async {
    try {
      final employeeId = leaveData['employee_id'] as String?;
      final organizationId = leaveData['organization_id'] as String?;
      final startDateStr = leaveData['start_date'] as String?;
      final endDateStr = leaveData['end_date'] as String?;
      final leaveTypeData = leaveData['leave_types'] as Map<String, dynamic>? ?? {};
      final leaveTypeCode = (leaveTypeData['code'] as String? ?? '').toLowerCase();
      final leaveTypeName = (leaveTypeData['name'] as String? ?? '').toLowerCase();

      if (employeeId == null || startDateStr == null || endDateStr == null) return;

      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);
      final now = DateTime.now().toUtc();

      // Determine calendar status based on leave type code/name
      String calendarStatus = 'planned_leave'; // Default
      String? workType;
      String statusField = 'On Leave';

      // Map leave types to calendar statuses
      if (leaveTypeCode.contains('remote') || leaveTypeCode.contains('wfh') || 
          leaveTypeName.contains('remote') || leaveTypeName.contains('work from home')) {
        calendarStatus = 'remote_wfh';
        workType = 'Remote';
        statusField = 'Present';
      } else if (leaveTypeCode.contains('borrowed') || leaveTypeName.contains('borrowed')) {
        calendarStatus = 'borrowed_day';
        workType = 'Remote';
        statusField = 'Present';
      }
      // else: default to planned_leave

      // Create/update attendance records for each day in the leave period
      DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

      while (!currentDate.isAfter(endDateOnly)) {
        final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

        // Check if attendance record already exists
        final existing = await supabase
            .from('attendance_records')
            .select()
            .eq('employee_id', employeeId)
            .eq('date', dateStr)
            .maybeSingle();

        final recordData = <String, dynamic>{
          'date': dateStr,
          'status': statusField,
          'updated_at': now.toIso8601String(),
        };

        if (workType != null) {
          recordData['work_type'] = workType;
        }

        if (calendarStatus == 'borrowed_day') {
          recordData['early_checkout_reason'] = 'BORROWED_DAY_MARKER';
        }

        if (organizationId != null) {
          recordData['organization_id'] = organizationId;
        }

        if (existing != null) {
          // Only update if there's no actual check-in (don't overwrite actual attendance)
          if (existing['check_in_time'] == null) {
            await supabase
                .from('attendance_records')
                .update(recordData)
                .eq('id', existing['id']);
          }
        } else {
          // Create new record
          recordData['employee_id'] = employeeId;
          await supabase
              .from('attendance_records')
              .insert(recordData);
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      print('Synced approved leave to calendar: ${leaveData['id']}');
    } catch (e) {
      print('Error syncing approved leave to calendar: $e');
    }
  }

  // Remove leave from calendar when rejected
  Future<void> _removeLeaveFromCalendar(Map<String, dynamic> leaveData) async {
    try {
      final employeeId = leaveData['employee_id'] as String?;
      final startDateStr = leaveData['start_date'] as String?;
      final endDateStr = leaveData['end_date'] as String?;

      if (employeeId == null || startDateStr == null || endDateStr == null) return;

      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);

      // Remove attendance records that were created from this leave (only if no check-in)
      DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
      final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

      while (!currentDate.isAfter(endDateOnly)) {
        final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

        final existing = await supabase
            .from('attendance_records')
            .select()
            .eq('employee_id', employeeId)
            .eq('date', dateStr)
            .maybeSingle();

        // Only delete if there's no check-in time (was only a calendar entry)
        if (existing != null && existing['check_in_time'] == null) {
          await supabase
              .from('attendance_records')
              .delete()
              .eq('id', existing['id']);
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      print('Removed rejected leave from calendar: ${leaveData['id']}');
    } catch (e) {
      print('Error removing leave from calendar: $e');
    }
  }
}

