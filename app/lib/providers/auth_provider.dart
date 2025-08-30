import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _currentUser != null;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _loadStoredAuth();
    notifyListeners(); // Ensure UI updates after loading
  }

  Future<void> _loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      final storedUserData = prefs.getString('user_data');

      debugPrint('Loading stored auth - Token: ${storedToken != null ? 'Found' : 'Not found'}, User: ${storedUserData != null ? 'Found' : 'Not found'}');

      if (storedToken != null && storedUserData != null) {
        _token = storedToken;
        try {
          final userMap = jsonDecode(storedUserData);
          _currentUser = User.fromJson(userMap);
          
          debugPrint('Stored session loaded for user: ${_currentUser?.name}');
          
          // Validate token with server
          final isValid = await validateToken();
          if (!isValid) {
            debugPrint('Token validation failed, clearing session');
            await _clearStoredAuth();
          } else {
            debugPrint('Token validation successful');
          }
        } catch (e) {
          debugPrint('Error parsing stored user data: $e');
          await _clearStoredAuth();
        }
      } else {
        debugPrint('No stored session found');
      }
    } catch (e) {
      debugPrint('Error loading stored auth: $e');
      await _clearStoredAuth();
    }
  }

  Future<bool> validateToken() async {
    try {
      // Call a simple API endpoint to validate token
      final response = await ApiService.validateToken(_token!);
      return response['valid'] == true;
    } catch (e) {
      debugPrint('Token validation failed: $e');
      return false;
    }
  }

  Future<void> _clearStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
    } catch (e) {
      debugPrint('Error clearing stored auth: $e');
    }
    _token = null;
    _currentUser = null;
  }

  Future<void> _saveAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString('auth_token', _token!);
        debugPrint('Auth token saved');
      }
      if (_currentUser != null) {
        await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
        debugPrint('User data saved for: ${_currentUser!.name}');
      }
    } catch (e) {
      debugPrint('Error saving auth data: $e');
    }
  }

  Future<bool> login(String email, String password,
      {bool rememberMe = true}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.login(email, password);

      if (response['access_token'] != null) {
        _token = response['access_token'];
        _currentUser = User.fromJson(response['user']);
        // Always save auth data for session persistence
        await _saveAuthData();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['detail'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
      String name, String email, String password, String phone) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.register(name, email, password, phone);

      if (response['access_token'] != null) {
        _token = response['access_token'];
        _currentUser = User.fromJson(response['user']);
        await _saveAuthData();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['detail'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }

    _currentUser = null;
    _token = null;
    _error = null;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null || _token == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final response = await ApiService.updateProfile(updates, _token!);

      if (response['access_token'] != null || response['user'] != null) {
        if (response['user'] != null) {
          _currentUser = User.fromJson(response['user']);
        }
        await _saveAuthData();
        _error = null;
      } else {
        _error = response['detail'] ?? 'Profile update failed';
      }
    } catch (e) {
      _error = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
