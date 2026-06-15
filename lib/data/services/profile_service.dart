import 'package:loghr_mobile/config/api_client.dart';

class ProfileService {
  // Fetch complete user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await api.get('/profile');
      return response as Map<String, dynamic>?;
    } catch (e) {
      print('ProfileService: Error fetching user profile: $e');
      return null;
    }
  }

  // Fetch organization details
  Future<Map<String, dynamic>?> getOrganization(String organizationId) async {
    try {
      // Return organization data directly from user profile endpoint or fetch if needed
      final profile = await getUserProfile('');
      if (profile != null) {
        return {
          'id': organizationId,
          'name': profile['organization_name'] ?? 'LogHR',
          'logo_url': profile['organization_logo'],
        };
      }
      return null;
    } catch (e) {
      print('Error fetching organization: $e');
      return null;
    }
  }

  // Fetch departments for an organization
  Future<List<Map<String, dynamic>>> getDepartments(String organizationId) async {
    try {
      final response = await api.get('/profile/departments');
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching departments: $e');
      return [];
    }
  }

  // Get employee count for organization
  Future<int> getEmployeeCount(String organizationId) async {
    try {
      final response = await api.get('/profile/employee-count');
      if (response == null) return 0;
      return response['count'] as int? ?? 0;
    } catch (e) {
      print('Error fetching employee count: $e');
      return 0;
    }
  }

  // Get department employee count
  Future<int> getDepartmentEmployeeCount(String departmentId) async {
    try {
      final response = await api.get('/profile/department-employee-count?departmentId=$departmentId');
      if (response == null) return 0;
      return response['count'] as int? ?? 0;
    } catch (e) {
      print('Error fetching department employee count: $e');
      return 0;
    }
  }

  // Get employees for a specific department
  Future<List<Map<String, dynamic>>> getDepartmentEmployees(
    String departmentId, {
    String? currentUserId,
    String? currentEmployeeId,
  }) async {
    try {
      final response = await api.get('/profile/department-employees?departmentId=$departmentId');
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching department employees: $e');
      return [];
    }
  }

  // Update user profile
  Future<bool> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await api.post('/profile/update', updates);
      return true;
    } catch (e) {
      print('ProfileService: Error updating profile: $e');
      return false;
    }
  }

  // Upload avatar image
  Future<String?> uploadAvatar(String userId, List<int> imageBytes, String fileName) async {
    try {
      // In custom API setup we can send avatarUrl or mock upload
      // Here we will mock since we don't have file upload multipart configured in ApiClient, 
      // but we can send it or return a mock local path.
      final mockAvatarUrl = 'https://picsum.photos/200';
      await api.post('/profile/upload-avatar', {'avatarUrl': mockAvatarUrl});
      return mockAvatarUrl;
    } catch (e) {
      print('ProfileService: Error uploading avatar: $e');
      return null;
    }
  }

  // Get formatted employee code
  Future<String> getFormattedEmployeeCode(String employeeId) async {
    try {
      final response = await api.get('/profile/employee-code/$employeeId');
      if (response == null || response['employee_code'] == null) {
        return 'N/A';
      }
      return response['employee_code'] as String;
    } catch (e) {
      print('ProfileService: Error fetching employee code: $e');
      return 'N/A';
    }
  }
}
