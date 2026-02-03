import 'package:loghr_mobile/data/services/profile_service.dart';

class ProfileRepository {
  final ProfileService _service = ProfileService();

  Future<Map<String, dynamic>?> getUserProfile(String userId) {
    return _service.getUserProfile(userId);
  }

  Future<Map<String, dynamic>?> getOrganization(String organizationId) {
    return _service.getOrganization(organizationId);
  }

  Future<List<Map<String, dynamic>>> getDepartments(String organizationId) {
    return _service.getDepartments(organizationId);
  }

  Future<int> getEmployeeCount(String organizationId) {
    return _service.getEmployeeCount(organizationId);
  }

  Future<int> getDepartmentEmployeeCount(String departmentId) {
    return _service.getDepartmentEmployeeCount(departmentId);
  }

  Future<List<Map<String, dynamic>>> getDepartmentEmployees(
    String departmentId, {
    String? currentUserId,
    String? currentEmployeeId,
  }) {
    return _service.getDepartmentEmployees(
      departmentId,
      currentUserId: currentUserId,
      currentEmployeeId: currentEmployeeId,
    );
  }

  Future<String> getFormattedEmployeeCode(String employeeId) {
    return _service.getFormattedEmployeeCode(employeeId);
  }

  Future<bool> updateProfile(String userId, Map<String, dynamic> updates) {
    return _service.updateProfile(userId, updates);
  }

  Future<String?> uploadAvatar(String userId, List<int> imageBytes, String fileName) {
    return _service.uploadAvatar(userId, imageBytes, fileName);
  }
}

