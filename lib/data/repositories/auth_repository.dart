import 'package:loghr_mobile/data/models/user.dart';
import 'package:loghr_mobile/data/services/auth_service.dart';

class AuthRepository {
  final AuthService _service;

  AuthRepository(this._service);

  Future<User?> login(String email, String password) async {
    return await _service.login(email, password);
  }

  Future<User?> signUp(String email, String password, String fullName) async {
    return await _service.signUp(email, password, fullName);
  }

  Future<void> logout() async {
    await _service.logout();
  }

  Future<User?> loadUserFromSession() async {
    return await _service.loadUserFromSession();
  }
}


