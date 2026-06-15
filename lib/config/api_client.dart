import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _token;
  String? _baseUrl;
  String? currentUserId;
  String? currentUserEmail;

  Future<void> initialize() async {
    _baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:5000/api';
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    currentUserId = prefs.getString('auth_user_id');
    currentUserEmail = prefs.getString('auth_user_email');
  }

  String get baseUrl => _baseUrl ?? 'http://localhost:5000/api';

  bool get isAuthenticated => _token != null;

  String? get token => _token;

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      currentUserId = null;
      currentUserEmail = null;
      await prefs.remove('auth_token');
      await prefs.remove('auth_user_id');
      await prefs.remove('auth_user_email');
    } else {
      await prefs.setString('auth_token', token);
    }
  }

  Future<void> setSession(String? token, String? userId, String? email) async {
    _token = token;
    currentUserId = userId;
    currentUserEmail = email;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('auth_token');
      await prefs.remove('auth_user_id');
      await prefs.remove('auth_user_email');
    } else {
      await prefs.setString('auth_token', token);
      if (userId != null) await prefs.setString('auth_user_id', userId);
      if (email != null) await prefs.setString('auth_user_email', email);
    }
  }

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      // Clear invalid token
      setToken(null);
      throw Exception('Unauthorized access. Please login again.');
    } else {
      final body = response.body;
      String errorMessage = 'Request failed with status ${response.statusCode}';
      try {
        final errorJson = jsonDecode(body);
        if (errorJson['error'] != null) {
          errorMessage = errorJson['error'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<dynamic> get(String path) async {
    if (_baseUrl == null) await initialize();
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await http.get(url, headers: _getHeaders());
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> post(String path, dynamic body) async {
    if (_baseUrl == null) await initialize();
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> put(String path, dynamic body) async {
    if (_baseUrl == null) await initialize();
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await http.put(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> delete(String path) async {
    if (_baseUrl == null) await initialize();
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await http.delete(url, headers: _getHeaders());
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

final api = ApiClient();

class RealtimeChannel {
  void unsubscribe() {
    print('Mock RealtimeChannel: Unsubscribed');
  }
}
