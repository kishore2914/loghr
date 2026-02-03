import 'package:loghr_mobile/data/models/user.dart' as models;
import 'package:loghr_mobile/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loghr_mobile/data/services/profile_service.dart';

class AuthService {
  final ProfileService _profileService = ProfileService();
  Future<models.User?> login(String email, String password) async {
    try {
      print('Attempting login for: $email');
      
      // Sign in with Supabase Auth
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('Auth response user: ${response.user?.id}');
      print('Auth response session: ${response.session != null}');

      if (response.user == null) {
        print('Login failed: No user returned from auth');
        return null;
      }

      print('Fetching user profile from user_profiles table...');
      
      Map<String, dynamic> userData;
      
      try {
        // Fetch user profile from user_profiles table using the user_id column
        userData = await supabase
            .from('user_profiles')
            .select()
            .eq('user_id', response.user!.id)
            .single();
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST116') {
          print('User profile not found. Creating new profile for user_id: ${response.user!.id}');
          
          // Auto-create profile if missing
          final newProfile = {
            'user_id': response.user!.id,
            'full_name': 'New Employee', // Default name
            'role': 'employee',
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
          };
          
          userData = await supabase
              .from('user_profiles')
              .insert(newProfile)
              .select()
              .single();
              
          print('Created new profile: $userData');
        } else {
          rethrow;
        }
      }

      // ALWAYS fetch employee name from employees table (prioritized)
      final employeeId = userData['employee_id'] as String?;
      if (employeeId != null && employeeId.isNotEmpty) {
        final empName = await _resolveEmployeeName(employeeId);
        if (empName != null) {
          userData['full_name'] = empName;
        }
      }

      // Convert to User model and inject the email from Auth
      final user = models.User.fromJson(userData);
      return user.copyWith(email: response.user?.email);
      
    } on AuthException catch (e) {
      print('Auth error: ${e.message} (${e.statusCode})');
      throw 'Authentication Failed: ${e.message}';
    } on PostgrestException catch (e) {
      print('Database error: ${e.message} (${e.code})');
      if (e.code == '42501') {
         throw 'Permission Denied: You access to user profile is blocked. (RLS Policy Error)';
      }
      throw 'Database Error: ${e.message}';
    } catch (e) {
      print('Unexpected login error: $e');
      throw 'System Error: $e';
    }
  }

  Future<models.User?> signUp(String email, String password, String fullName) async {
    try {
      print('Attempting signup for: $email');
      
      // Create user in Supabase Auth
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw 'Signup failed: Unable to create user account';
      }

      // Create user profile
      final newProfile = {
        'user_id': response.user!.id,
        'full_name': fullName,
        'role': 'employee',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final userData = await supabase
          .from('user_profiles')
          .insert(newProfile)
          .select()
          .single();
          
      // Convert to User model and inject the email from Auth
      final user = models.User.fromJson(userData);
      return user.copyWith(email: response.user?.email);
      
    } on AuthException catch (e) {
      throw 'Signup Failed: ${e.message}';
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
         throw 'Permission Denied: Unable to create user profile. (RLS Policy Error)';
      }
      throw 'Database Error: ${e.message}';
    } catch (e) {
      throw 'System Error: $e';
    }
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  Future<models.User?> loadUserFromSession() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return null;

      final userData = await supabase
          .from('user_profiles')
          .select()
          .eq('user_id', session.user.id)
          .maybeSingle();

      if (userData == null) {
        // Try to create a default profile if missing
        try {
          final newProfile = {
            'user_id': session.user.id,
            'full_name': session.user.email?.split('@')[0] ?? 'User',
            'role': 'employee',
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
          };
          
          final createdProfile = await supabase
              .from('user_profiles')
              .insert(newProfile)
              .select()
              .single();
          
          final user = models.User.fromJson(createdProfile);
          return user.copyWith(email: session.user.email);
        } catch (e) {
          return null;
        }
      }

      // ALWAYS fetch employee name from employees table (prioritized)
      final employeeId = userData['employee_id'] as String?;
      if (employeeId != null && employeeId.isNotEmpty) {
        final empName = await _resolveEmployeeName(employeeId);
        if (empName != null) {
          userData['full_name'] = empName;
        }
      }
      
      final user = models.User.fromJson(userData);
      return user.copyWith(email: session.user.email);
    } catch (e) {
      print('Load user from session error: $e');
      return null;
    }
  }

  /// Robustly resolve employee name by looking up by ID or Employee Code
  Future<String?> _resolveEmployeeName(String employeeId) async {
    try {
      // 1. Try by ID (UUID)
      var data = await supabase
          .from('employees')
          .select()
          .eq('id', employeeId)
          .maybeSingle();
      
      // 2. Try by employee_code as fallback
      if (data == null) {
        data = await supabase
            .from('employees')
            .select()
            .eq('employee_code', employeeId)
            .maybeSingle();
      }
      
      if (data != null) {
        // Construct name prioritizing first_name/last_name
        final firstName = data['first_name'] as String?;
        final lastName = data['last_name'] as String?;
        String? constructedName;
        if (firstName != null && firstName.trim().isNotEmpty) {
          constructedName = firstName.trim();
          if (lastName != null && lastName.trim().isNotEmpty) {
            constructedName = '$constructedName ${lastName.trim()}';
          }
        }

        final empName = constructedName ?? 
                       data['full_name'] as String? ?? 
                       data['display_name'] as String? ??
                       data['name'] as String? ??
                       data['employee_name'] as String?;
        
        if (empName != null && empName.trim().isNotEmpty) {
          final resolvedName = empName.trim();
          print('AuthService: ✅ Successfully resolved name from employees table: "$resolvedName"');
          return resolvedName;
        }
      }
    } catch (e) {
      print('AuthService: Error resolving employee name: $e');
    }
    return null;
  }
}
