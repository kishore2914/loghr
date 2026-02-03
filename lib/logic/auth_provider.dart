import 'package:flutter/foundation.dart';
import 'package:loghr_mobile/data/models/user.dart';
import 'package:loghr_mobile/data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  User? _user;
  bool _isInitializing = true;

  AuthProvider(this._repository) {
    checkSession();
  }

  User? get user => _user;
  bool get isInitializing => _isInitializing;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password) async {
    try {
      _user = await _repository.login(email, password);
      notifyListeners();
      return _user != null;
    } catch (e) {
      // Rethrow to let the UI know what went wrong
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    notifyListeners();
  }

  Future<void> checkSession() async {
    try {
      _isInitializing = true;
      notifyListeners();
      
      _user = await _repository.loadUserFromSession();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }
}


