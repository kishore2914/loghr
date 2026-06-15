import 'package:loghr_mobile/data/models/user.dart' as models;
import 'package:loghr_mobile/config/api_client.dart';

class AuthService {
  Future<models.User?> login(String email, String password) async {
    try {
      print('Attempting custom API login for: $email');
      
      final response = await api.post('/auth/signin', {
        'email': email,
        'password': password,
      });

      if (response == null) {
        print('Login failed: Invalid server response');
        return null;
      }

      String? token;
      if (response['session'] != null && response['session']['access_token'] != null) {
        token = response['session']['access_token'] as String;
      } else if (response['token'] != null) {
        token = response['token'] as String;
      }

      final Map<String, dynamic>? userData = response['user'] != null 
          ? Map<String, dynamic>.from(response['user']) 
          : null;

      if (token == null || userData == null) {
        print('Login failed: Missing token or user data in response');
        return null;
      }

      final user = models.User.fromJson(userData);
      await api.setSession(token, user.id, user.email);

      return user;
    } catch (e) {
      print('Login error: $e');
      throw e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<models.User?> signUp(String email, String password, String fullName) async {
    try {
      print('Attempting custom API signup for: $email');
      
      final response = await api.post('/auth/signup', {
        'email': email,
        'password': password,
        'fullName': fullName,
      });

      if (response == null) {
        print('Signup failed: Invalid server response');
        return null;
      }

      String? token;
      if (response['session'] != null && response['session']['access_token'] != null) {
        token = response['session']['access_token'] as String;
      } else if (response['token'] != null) {
        token = response['token'] as String;
      }

      final Map<String, dynamic>? userData = response['user'] != null 
          ? Map<String, dynamic>.from(response['user']) 
          : null;

      if (token == null || userData == null) {
        print('Signup failed: Missing token or user data in response');
        return null;
      }

      final user = models.User.fromJson(userData);
      await api.setSession(token, user.id, user.email);

      return user;
    } catch (e) {
      print('Signup error: $e');
      throw e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> logout() async {
    try {
      await api.setSession(null, null, null);
    } catch (e) {
      print('Logout error: $e');
    }
  }

  Future<models.User?> loadUserFromSession() async {
    try {
      // First initialize client to check saved token
      await api.initialize();
      if (!api.isAuthenticated) return null;

      print('Loading user from custom API session...');
      final response = await api.get('/auth/me');
      
      if (response == null) return null;
      final user = models.User.fromJson(response);
      await api.setSession(api.token, user.id, user.email);
      return user;
    } catch (e) {
      print('Load user from session error: $e');
      // If token is invalid or expired, reset it
      await api.setSession(null, null, null);
      return null;
    }
  }
}
