import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:loghr_mobile/data/models/attendance.dart';
import 'package:loghr_mobile/utils/constants.dart';
import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:loghr_mobile/data/services/loyalty_service.dart';

class AttendanceService {
  // Helper method to get employee_id and organization_id from user_id
  Future<Map<String, String?>> _getEmployeeInfo(String userId) async {
    try {
      // Get employee_id from user_profiles table (which links user_id to employee_id)
      final profileData = await supabase
          .from('user_profiles')
          .select('employee_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (profileData != null && profileData['employee_id'] != null) {
        final empId = profileData['employee_id'] as String;
        
        // Get organization_id from employees table using employee_id
        try {
          final empData = await supabase
              .from('employees')
              .select('id, organization_id')
              .eq('id', empId)
              .maybeSingle();
          
          if (empData != null) {
            return {
              'employee_id': empData['id'] as String?,
              'organization_id': empData['organization_id'] as String?,
            };
          }
        } catch (e) {
          // If employees table query fails, still return employee_id from user_profiles
          print('Error querying employees table: $e');
        }
        
        // Return employee_id even if we couldn't get organization_id
        return {
          'employee_id': empId,
          'organization_id': null,
        };
      }
      
      // Fallback: use userId as employee_id if employee_id not found in user_profiles
      return {
        'employee_id': userId,
        'organization_id': null,
      };
    } catch (e) {
      print('Error getting employee info: $e');
      // Fallback: use userId as employee_id
      return {
        'employee_id': userId,
        'organization_id': null,
      };
    }
  }

  // Fetch office locations for an organization
  Future<List<Map<String, dynamic>>> _getOfficeLocations(String? organizationId) async {
    try {
      if (organizationId == null) {
        print('No organization_id provided, cannot fetch office locations');
        return [];
      }

      // Fetch only active office locations
      // Filter by is_active = true and only include locations with valid coordinates
      final locations = await supabase
          .from('office_locations')
          .select('id, name, address, city, state, country, latitude, longitude, radius_meters, requires_gps, is_active')
          .eq('organization_id', organizationId)
          .eq('is_active', true)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      // Filter to only include locations that require GPS verification (defaults to true if null)
      final gpsRequiredLocations = (locations as List)
          .where((loc) {
            final requiresGps = loc['requires_gps'];
            // If requires_gps is null, default to true (as per schema default)
            return requiresGps != false;
          })
          .toList();
      
      print('Fetched ${gpsRequiredLocations.length} active office locations (with GPS enabled) for organization: $organizationId');
      return gpsRequiredLocations.map((loc) => loc as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error fetching office locations: $e');
      return [];
    }
  }

  // Find the nearest office location within radius
  Map<String, dynamic>? _findNearestOfficeLocation(
    double latitude,
    double longitude,
    List<Map<String, dynamic>> officeLocations,
  ) {
    Map<String, dynamic>? nearestLocation;
    double minDistance = double.infinity;

    for (final location in officeLocations) {
      final officeLat = (location['latitude'] as num?)?.toDouble();
      final officeLon = (location['longitude'] as num?)?.toDouble();
      final radius = (location['radius_meters'] as num?)?.toDouble() ?? AppConstants.geofenceRadius;

      if (officeLat == null || officeLon == null) continue;

      final distance = _calculateDistance(latitude, longitude, officeLat, officeLon);

      if (distance <= radius && distance < minDistance) {
        minDistance = distance;
        nearestLocation = location;
      }
    }

    return nearestLocation;
  }

  // Check for incomplete checkout from previous day
  Future<Attendance?> getIncompleteCheckoutFromPreviousDay(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = today.toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      // Get employee_id
      final employeeInfo = await _getEmployeeInfo(userId);
      final employeeId = employeeInfo['employee_id'] ?? userId;
      
      // Find attendance records with check-in but no check-out, excluding today
      final data = await supabase
          .from('attendance_records')
          .select()
          .eq('employee_id', employeeId)
          .not('check_in_time', 'is', null)
          .isFilter('check_out_time', null)
          .lt('date', todayStr)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      
      return Attendance.fromJson(data);
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
      // Check for incomplete checkout from previous day
      final incompleteCheckout = await getIncompleteCheckoutFromPreviousDay(userId);
      if (incompleteCheckout != null) {
        final incompleteDate = DateFormat('MMM dd, yyyy').format(incompleteCheckout.date);
        throw Exception('You have an incomplete checkout from $incompleteDate. Please complete the checkout for that day before checking in again.');
      }

      // Use UTC time for database storage to ensure consistency
      final now = DateTime.now().toUtc();
      final today = DateTime(now.year, now.month, now.day);
      final dateStr = today.toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      // Get employee_id and organization_id
      final employeeInfo = await _getEmployeeInfo(userId);
      final employeeId = employeeInfo['employee_id'] ?? userId;
      final organizationId = employeeInfo['organization_id'];
      
      // Determine work type based on location
      String workType = 'Remote';
      String? locationId;
      String? checkInLocationId;
      bool gpsVerified = false;

      // Fetch office locations and check if employee is at office
      if (organizationId != null) {
        final officeLocations = await _getOfficeLocations(organizationId);
        final nearestOffice = _findNearestOfficeLocation(latitude, longitude, officeLocations);

        if (nearestOffice != null) {
          workType = 'In Office';
          locationId = nearestOffice['id'] as String?;
          checkInLocationId = nearestOffice['id'] as String?;
          gpsVerified = true;
          print('Employee checked in at office location: ${nearestOffice['name']}');
        } else {
          print('Employee checked in remotely (not within any office location radius)');
        }
      } else {
        print('No organization_id found, defaulting to Remote work type');
      }
      
      // Check if attendance record already exists for today
      final existing = await supabase
          .from('attendance_records')
          .select()
          .eq('employee_id', employeeId)
          .eq('date', dateStr)
          .maybeSingle();
      
      Map<String, dynamic> data;
      
      if (existing != null) {
        // Update existing record
        final updateData = {
          'check_in_latitude': latitude,
          'check_in_longitude': longitude,
          'check_in_location': address,
          'work_type': workType,
          'gps_verified': gpsVerified,
          'check_out_time': null,
          'check_out_latitude': null,
          'check_out_longitude': null,
          'check_out_location': null,
          // Keep early_checkout_reason if it exists
        };

        if (locationId != null) {
          updateData['location_id'] = locationId;
        }
        if (checkInLocationId != null) {
          updateData['check_in_location_id'] = checkInLocationId;
        }
        
        data = await supabase
            .from('attendance_records')
            .update(updateData)
            .eq('id', existing['id'])
            .select()
            .single();
      } else {
        // Insert new record
        final insertData = {
          'employee_id': employeeId,
          'date': dateStr,
          'check_in_time': now.toIso8601String(),
          'check_in_latitude': latitude,
          'check_in_longitude': longitude,
          'check_in_location': address,
          'work_type': workType,
          'gps_verified': gpsVerified,
        };
        
        if (organizationId != null) {
          insertData['organization_id'] = organizationId;
        }
        if (locationId != null) {
          insertData['location_id'] = locationId;
        }
        if (checkInLocationId != null) {
          insertData['check_in_location_id'] = checkInLocationId;
        }
        
        data = await supabase
            .from('attendance_records')
            .insert(insertData)
            .select()
            .single();
      }

      // Award 5 loyalty points for on-time check-in (before 9:05 AM local time)
      try {
        final checkInLocal = now.toLocal();
        if (checkInLocal.hour < 9 || (checkInLocal.hour == 9 && checkInLocal.minute <= 5)) {
          await LoyaltyService().awardPoints(
            employeeId: employeeId,
            points: 5,
            type: 'attendance',
            description: 'On-time check-in',
          );
        }
      } catch (e) {
        print('Error awarding loyalty points for on-time check-in: $e');
      }

      return Attendance.fromJson(data);
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
      // Use UTC time for database storage to ensure consistency
      final now = DateTime.now().toUtc();
      
      // Get employee_id and organization_id for verification
      final employeeInfo = await _getEmployeeInfo(userId);
      final employeeId = employeeInfo['employee_id'] ?? userId;
      final organizationId = employeeInfo['organization_id'];
      
      // Get current attendance record to check work_type
      final currentRecord = await supabase
          .from('attendance_records')
          .select('work_type, location_id, check_in_location_id')
          .eq('id', attendanceId)
          .eq('employee_id', employeeId)
          .maybeSingle();
      
      String? workType = currentRecord?['work_type'] as String?;
      String? checkOutLocationId;
      bool gpsVerified = false;
      
      // For auto-checkout, preserve the check-in work_type and try to get office location.
      if (isAutoCheckout) {
        final checkInLocationId = currentRecord?['check_in_location_id'] as String?;
        if (checkInLocationId != null) {
          try {
            final office = await supabase
                .from('office_locations')
                .select('latitude, longitude, address, name')
                .eq('id', checkInLocationId)
                .maybeSingle();
                
            if (office != null) {
              latitude = (office['latitude'] as num?)?.toDouble() ?? latitude;
              longitude = (office['longitude'] as num?)?.toDouble() ?? longitude;
              address = office['address'] as String? ?? office['name'] as String? ?? address;
              checkOutLocationId = checkInLocationId;
              gpsVerified = true;
              print('Auto-checkout: Using office location details for $checkInLocationId');
            }
          } catch (e) {
            print('Error fetching office location for auto-checkout: $e');
          }
        }
      } else if (organizationId != null) {
        final officeLocations = await _getOfficeLocations(organizationId);
        final nearestOffice = _findNearestOfficeLocation(latitude, longitude, officeLocations);
        
        if (nearestOffice != null) {
          checkOutLocationId = nearestOffice['id'] as String?;
          gpsVerified = true;
          
          // If checked in remotely but checking out at office (or vice versa), set to Hybrid
          if (workType == 'Remote') {
            workType = 'Hybrid';
            print('Employee checked in remotely but checking out at office - setting work_type to Hybrid');
          }
        } else {
          // If checked in at office but checking out remotely, set to Hybrid
          if (workType == 'In Office') {
            workType = 'Hybrid';
            print('Employee checked in at office but checking out remotely - setting work_type to Hybrid');
          }
        }
      }
      
      // Update attendance record
      final updateData = {
        'check_out_time': now.toIso8601String(),
        'check_out_latitude': latitude,
        'check_out_longitude': longitude,
        'check_out_location': address,
        'gps_verified': gpsVerified,
      };
      
      if (workType != null) {
        updateData['work_type'] = workType;
      }
      if (checkOutLocationId != null) {
        updateData['location_id'] = checkOutLocationId;
      }
      
      // Only update early_checkout_reason if a new one is provided (i.e. it's an early checkout)
      // This preserves any previous early checkout reason if they re-checked in and then checked out normally.
      if (earlyCheckoutReason != null) {
        updateData['early_checkout_reason'] = earlyCheckoutReason;
      }

      final data = await supabase
          .from('attendance_records')
          .update(updateData)
          .eq('id', attendanceId)
          .eq('employee_id', employeeId)
          .select()
          .single();

      return Attendance.fromJson(data);
    } catch (e) {
      print('Check-out error: $e');
      rethrow;
    }
  }

  Future<Attendance?> getTodayAttendance(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateStr = today.toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      // Get employee_id
      final employeeInfo = await _getEmployeeInfo(userId);
      final employeeId = employeeInfo['employee_id'] ?? userId;
      
      final data = await supabase
          .from('attendance_records')
          .select()
          .eq('employee_id', employeeId)
          .eq('date', dateStr)
          .maybeSingle();

      if (data == null) return null;
      
      return Attendance.fromJson(data);
    } catch (e) {
      print('Get today attendance error: $e');
      return null;
    }
  }

  Future<List<Attendance>> getHistory(String userId) async {
    try {
      // Get employee_id
      final employeeInfo = await _getEmployeeInfo(userId);
      final employeeId = employeeInfo['employee_id'] ?? userId;
      
      // Fetch all attendance records including future dates with calendar status
      // Only show approved calendar statuses or actual check-in records
      final data = await supabase
          .from('attendance_records')
          .select()
          .eq('employee_id', employeeId)
          .order('date', ascending: false);

      // Filter out pending requests (only show approved or actual check-ins)
      final filteredData = (data as List).where((record) {
        // If there's a check_in_time, it's an actual attendance record - show it
        if (record['check_in_time'] != null) return true;
        
        // Check if this is a pending calendar request (stored in early_checkout_reason)
        final reason = record['early_checkout_reason'] as String?;
        if (reason != null && reason.startsWith('CALENDAR_REQUEST:')) {
          // Extract approval status from the encoded string
          final parts = reason.split('|');
          if (parts.length >= 4) {
            final approval = parts[3];
            // Only show if approved, not pending
            return approval == 'approved';
          }
        }
        
        // Show records without calendar request markers (legacy/approved)
        return true;
      }).toList();

      return filteredData.map((json) => Attendance.fromJson(json)).toList();
    } catch (e) {
      print('Get attendance history error: $e');
      return [];
    }
  }

  // Get pending calendar status requests (for admin)
  Future<List<Map<String, dynamic>>> getPendingCalendarRequests(String organizationId) async {
    try {
      // Fetch all records for the organization without check-in time
      final data = await supabase
          .from('attendance_records')
          .select('''
            *,
            employees(id, full_name, employee_id)
          ''')
          .eq('organization_id', organizationId)
          .isFilter('check_in_time', null)
          .order('updated_at', ascending: false);

      // Filter for pending calendar requests
      final pendingRequests = (data as List).where((record) {
        final reason = record['early_checkout_reason'] as String?;
        if (reason != null && reason.startsWith('CALENDAR_REQUEST:')) {
          final parts = reason.split('|');
          if (parts.length >= 4) {
            return parts[3] == 'pending';
          }
        }
        return false;
      }).toList();

      return pendingRequests.map((record) => record as Map<String, dynamic>).toList();
    } catch (e) {
      print('Get pending calendar requests error: $e');
      return [];
    }
  }

  // Approve or reject calendar status request (admin only)
  Future<bool> approveCalendarStatusRequest({
    required String attendanceId,
    required bool approve,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      
      // Get the request details
      final request = await supabase
          .from('attendance_records')
          .select()
          .eq('id', attendanceId)
          .maybeSingle();

      if (request == null) return false;

      final reason = request['early_checkout_reason'] as String?;
      if (reason == null || !reason.startsWith('CALENDAR_REQUEST:')) {
        return false; // Not a calendar request
      }

      final parts = reason.split('|');
      if (parts.length < 4) return false;

      final requestedStatus = parts[0].replaceFirst('CALENDAR_REQUEST:', '');
      final requestedStatusField = parts.length > 1 ? parts[1] : null;
      final requestedWorkType = parts.length > 2 ? parts[2] : null;

      if (approve) {
        // Apply the requested status
        final updateData = <String, dynamic>{
          'status': requestedStatusField ?? 'Present',
        };

        if (requestedWorkType != null && requestedWorkType.isNotEmpty) {
          updateData['work_type'] = requestedWorkType;
        }

        // Handle borrowed_day marker
        if (requestedStatus == 'borrowed_day') {
          updateData['early_checkout_reason'] = 'BORROWED_DAY_MARKER';
        } else {
          updateData['early_checkout_reason'] = null;
        }

        await supabase
            .from('attendance_records')
            .update(updateData)
            .eq('id', attendanceId);

        print('Calendar status request approved for attendance: $attendanceId');
      } else {
        // Reject: Update the marker to rejected
        await supabase
            .from('attendance_records')
            .update({
              'early_checkout_reason': 'CALENDAR_REQUEST:${requestedStatus}|${requestedStatusField ?? ''}|${requestedWorkType ?? ''}|rejected',
            })
            .eq('id', attendanceId);

        print('Calendar status request rejected for attendance: $attendanceId');
      }

      return true;
    } catch (e) {
      print('Approve/reject calendar status request error: $e');
      return false;
    }
  }

  bool isWithinGeofence(double latitude, double longitude) {
    final distance = _calculateDistance(
      latitude,
      longitude,
      AppConstants.defaultLatitude,
      AppConstants.defaultLongitude,
    );
    return distance <= AppConstants.geofenceRadius;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Haversine formula
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }

  // Request calendar status change (pending admin approval)
  Future<bool> requestCalendarStatus({
    required String userId,
    required DateTime date,
    required String status, // 'active_in_office', 'planned_leave', 'remote_wfh', 'borrowed_day'
  }) async {
    try {
      print('AttendanceService: Requesting calendar status for date: $date, status: $status');
      
      // Get employee_id
      final employeeInfo = await _getEmployeeInfo(userId);
      final employeeId = employeeInfo['employee_id'] ?? userId;
      final organizationId = employeeInfo['organization_id'];
      
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final now = DateTime.now().toUtc();
      
      // Map status to work_type and status field
      String? requestedWorkType;
      String? requestedStatus;
      
      switch (status) {
        case 'active_in_office':
          requestedWorkType = 'In Office';
          requestedStatus = 'Present';
          break;
        case 'remote_wfh':
          requestedWorkType = 'Remote';
          requestedStatus = 'Present';
          break;
        case 'planned_leave':
          requestedStatus = 'On Leave';
          requestedWorkType = null;
          break;
        case 'borrowed_day':
          requestedWorkType = 'Remote';
          requestedStatus = 'Present';
          break;
        default:
          print('AttendanceService: Unknown status: $status');
          return false;
      }
      
      // Check if there's already a request or record for this date
      final existing = await supabase
          .from('attendance_records')
          .select()
          .eq('employee_id', employeeId)
          .eq('date', dateStr)
          .maybeSingle();
      
      final requestData = {
        'employee_id': employeeId,
        'date': dateStr,
        'requested_status': status,
        'requested_work_type': requestedWorkType,
        'requested_status_field': requestedStatus,
        'status_approval': 'pending',
        // Use created_at or updated_at for timestamp instead of requested_at
        'updated_at': now.toIso8601String(),
      };
      
      if (organizationId != null) {
        requestData['organization_id'] = organizationId;
      }
      
      if (existing != null) {
        // Update existing record with pending request
        await supabase
            .from('attendance_records')
            .update(requestData)
            .eq('id', existing['id'])
            .eq('employee_id', employeeId);
      } else {
        // Create new record with pending request
        await supabase
            .from('attendance_records')
            .insert(requestData);
      }
      
      print('AttendanceService: Created/updated calendar status request for date: $dateStr');
      return true;
    } catch (e, stackTrace) {
      print('AttendanceService: Error requesting calendar status: $e');
      print('AttendanceService: Stack trace: $stackTrace');
      return false;
    }
  }

  // Update calendar status for a specific date (approved by admin)
  Future<bool> updateCalendarStatus({
    required String userId,
    required DateTime date,
    required String status, // 'active_in_office', 'planned_leave', 'remote_wfh', 'borrowed_day'
  }) async {
    try {
      print('AttendanceService: Updating calendar status for date: $date, status: $status');
      
      // Get employee_id
      final employeeInfo = await _getEmployeeInfo(userId);
      final employeeId = employeeInfo['employee_id'] ?? userId;
      final organizationId = employeeInfo['organization_id'];
      
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final now = DateTime.now().toUtc();
      
      // Map status to work_type and status field
      // Note: status field has a check constraint, so we can only use allowed values
      // Valid status values are typically: 'Present', 'Absent', 'On Leave', etc.
      String? workType;
      String? statusField;
      
      switch (status) {
        case 'active_in_office':
          workType = 'In Office';
          statusField = 'Present'; // Use valid status value
          break;
        case 'remote_wfh':
          workType = 'Remote';
          statusField = 'Present'; // Remote work is still "Present"
          break;
        case 'planned_leave':
          // For planned leave, use "On Leave" which is likely a valid status value
          statusField = 'On Leave';
          workType = null; // Don't set work_type for planned leave
          break;
        case 'borrowed_day':
          // For borrowed day, use "Present" since it's a working day
          // We'll use earlyCheckoutReason field as a marker to distinguish from remote_wfh
          workType = 'Remote';
          statusField = 'Present'; // Use valid status value
          break;
        default:
          print('AttendanceService: Unknown status: $status');
          return false;
      }
      
      // Check if attendance record already exists for this date
      final existing = await supabase
          .from('attendance_records')
          .select()
          .eq('employee_id', employeeId)
          .eq('date', dateStr)
          .maybeSingle();
      
      Map<String, dynamic> updateData = {};
      
      // Set status field only if we have a valid value
      // For future dates without check-in, we might want to skip status
      // But for calendar planning, we'll set it to indicate the planned status
      if (statusField != null) {
        updateData['status'] = statusField;
      }
      
      // Set work_type for non-planned-leave statuses
      if (workType != null && status != 'planned_leave') {
        updateData['work_type'] = workType;
      }
      
      // Use earlyCheckoutReason field as a marker for "borrowed_day"
      // This helps distinguish it from "remote_wfh" which has the same status/work_type
      if (status == 'borrowed_day') {
        updateData['early_checkout_reason'] = 'BORROWED_DAY_MARKER';
      } else if (status != 'planned_leave') {
        // Clear the marker for other statuses (except planned_leave which doesn't set work_type)
        updateData['early_checkout_reason'] = null;
      }
      
      if (organizationId != null) {
        updateData['organization_id'] = organizationId;
      }
      
      // Always add updated_at
      updateData['updated_at'] = now.toIso8601String();
      
      // Mark as approved
      updateData['status_approval'] = 'approved';
      updateData['approved_at'] = now.toIso8601String();
      // Clear pending request fields
      updateData['requested_status'] = null;
      updateData['requested_work_type'] = null;
      updateData['requested_status_field'] = null;
      
      if (existing != null) {
        // Update existing record
        await supabase
            .from('attendance_records')
            .update(updateData)
            .eq('id', existing['id'])
            .eq('employee_id', employeeId);
        
        print('AttendanceService: Updated existing attendance record for date: $dateStr with status: $statusField, work_type: $workType');
      } else {
        // Create new record for future date
        final insertData = <String, dynamic>{
          'employee_id': employeeId,
          'date': dateStr,
          ...updateData,
        };
        
        await supabase
            .from('attendance_records')
            .insert(insertData);
        
        print('AttendanceService: Created new attendance record for date: $dateStr with status: $statusField, work_type: $workType');
      }
      
      return true;
    } catch (e, stackTrace) {
      print('AttendanceService: Error updating calendar status: $e');
      print('AttendanceService: Stack trace: $stackTrace');
      return false;
    }
  }
}
