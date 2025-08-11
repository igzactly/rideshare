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
    _loadStoredAuth();
  }

  Future<void> _loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      final storedUserData = prefs.getString('user_data');

      if (storedToken != null && storedUserData != null) {
        _token = storedToken;
        try {
          final userMap = jsonDecode(storedUserData);
          _currentUser = User.fromJson(userMap);
        } catch (e) {
          debugPrint('Error parsing stored user data: $e');
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading stored auth: $e');
    }
  }

  Future<void> _saveAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString('auth_token', _token!);
      }
      if (_currentUser != null) {
        await prefs.setString('user_data', jsonEncode(_currentUser!.toJson()));
      }
    } catch (e) {
      debugPrint('Error saving auth data: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.login(email, password);

      if (response['success'] == true) {
        _token = response['token'];
        _currentUser = User.fromJson(response['user']);
        await _saveAuthData();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Login failed';
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

      if (response['success'] == true) {
        _token = response['token'];
        _currentUser = User.fromJson(response['user']);
        await _saveAuthData();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Registration failed';
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

      if (response['success'] == true) {
        _currentUser = User.fromJson(response['user']);
        await _saveAuthData();
        _error = null;
      } else {
        _error = response['message'] ?? 'Profile update failed';
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
