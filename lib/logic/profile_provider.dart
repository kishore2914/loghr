import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/repositories/profile_repository.dart';
import 'package:loghr_mobile/data/services/payroll_service.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileRepository _repository = ProfileRepository();
  final PayrollService _payrollService = PayrollService();

  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _organizationData;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _payrollHistory = [];
  int _totalEmployees = 0;
  String? _formattedEmployeeCode;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get profileData => _profileData;
  Map<String, dynamic>? get organizationData => _organizationData;
  List<Map<String, dynamic>> get departments => _departments;
  List<Map<String, dynamic>> get payrollHistory => _payrollHistory;
  int get totalEmployees => _totalEmployees;
  String? get formattedEmployeeCode => _formattedEmployeeCode;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProfile(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load profile data - always fetch fresh from database
      _profileData = await _repository.getUserProfile(userId);
      
      print('ProfileProvider: Profile loaded - full_name: ${_profileData?['full_name']}');

      if (_profileData != null) {
        final employeeId = _profileData!['employee_id'] as String?;
        
        // Load formatted employee code
        if (employeeId != null && employeeId.isNotEmpty) {
          _formattedEmployeeCode = await _repository.getFormattedEmployeeCode(employeeId);
        }
        
        final organizationId = _profileData!['organization_id'] as String?;
        
        if (organizationId != null) {
          // Load organization data
          _organizationData = await _repository.getOrganization(organizationId);
          
          // Load total employee count for organization
          _totalEmployees = await _repository.getEmployeeCount(organizationId);
          
          // Load departments
          _departments = await _repository.getDepartments(organizationId);
          
          // Load employee counts for departments
          for (var dept in _departments) {
            final deptId = dept['id'] as String?;
            if (deptId != null) {
              final count = await _repository.getDepartmentEmployeeCount(deptId);
              dept['employee_count'] = count;
            } else {
              dept['employee_count'] = 0;
            }
          }
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('ProfileProvider: Error loading profile: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPayrollHistory(String userId, {int? month, int? year}) async {
    try {
      _payrollHistory = await _payrollService.getEmployeePayrollHistory(
        userId: userId,
        month: month,
        year: year,
      );
      notifyListeners();
    } catch (e) {
      print('Error loading payroll history: $e');
      _payrollHistory = [];
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getDepartmentEmployees(
    String departmentId, {
    String? currentUserId,
    String? currentEmployeeId,
  }) async {
    try {
      return await _repository.getDepartmentEmployees(
        departmentId,
        currentUserId: currentUserId,
        currentEmployeeId: currentEmployeeId,
      );
    } catch (e) {
      print('Error fetching department employees: $e');
      return [];
    }
  }

  Future<bool> uploadAvatar(String userId, List<int> imageBytes, String fileName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final avatarUrl = await _repository.uploadAvatar(userId, imageBytes, fileName);
      if (avatarUrl != null) {
        // Refresh profile data to get the new avatar_url
        await loadProfile(userId);
        return true;
      }
      _error = 'Failed to upload image. Please check your connection and try again.';
      return false;
    } catch (e) {
      print('ProfileProvider: Error uploading avatar: $e');
      _error = 'Error uploading avatar: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

