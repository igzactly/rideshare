import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;
  Timer? _sessionTimer;
  DateTime? _lastActivity;
  static const Duration _sessionTimeout = Duration(hours: 24); // 24 hours session timeout
  static const Duration _inactivityTimeout = Duration(minutes: 30); // 30 minutes inactivity timeout

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
      final storedLoginTime = prefs.getString('login_time');

      debugPrint('Loading stored auth - Token: ${storedToken != null ? 'Found' : 'Not found'}, User: ${storedUserData != null ? 'Found' : 'Not found'}');

      if (storedToken != null && storedUserData != null && storedLoginTime != null) {
        _token = storedToken;
        try {
          final userMap = jsonDecode(storedUserData);
          _currentUser = User.fromJson(userMap);
          final loginTime = DateTime.parse(storedLoginTime);
          
          debugPrint('Stored session loaded for user: ${_currentUser?.name}');
          
          // Check if session has expired
          if (DateTime.now().difference(loginTime) > _sessionTimeout) {
            debugPrint('Session expired, clearing auth');
            await _clearStoredAuth();
            return;
          }
          
          // Validate token with server
          final isValid = await validateToken();
          if (!isValid) {
            debugPrint('Token validation failed, clearing session');
            await _clearStoredAuth();
          } else {
            debugPrint('Token validation successful');
            _startSessionTimer();
            _lastActivity = DateTime.now();
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
      await prefs.remove('login_time');
    } catch (e) {
      debugPrint('Error clearing stored auth: $e');
    }
    _token = null;
    _currentUser = null;
    _stopSessionTimer();
    _lastActivity = null;
  }

  void _startSessionTimer() {
    _stopSessionTimer(); // Stop any existing timer
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkSessionValidity();
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  void _checkSessionValidity() {
    if (_lastActivity == null) return;
    
    final now = DateTime.now();
    final timeSinceLastActivity = now.difference(_lastActivity!);
    
    // Check inactivity timeout
    if (timeSinceLastActivity > _inactivityTimeout) {
      debugPrint('Session timed out due to inactivity');
      _handleSessionExpiry('Session expired due to inactivity');
      return;
    }
    
    // Check overall session timeout
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      final loginTimeStr = prefs.getString('login_time');
      if (loginTimeStr != null) {
        final loginTime = DateTime.parse(loginTimeStr);
        if (now.difference(loginTime) > _sessionTimeout) {
          debugPrint('Session expired due to time limit');
          _handleSessionExpiry('Session expired');
        }
      }
    });
  }

  void _handleSessionExpiry(String reason) {
    debugPrint('Handling session expiry: $reason');
    _stopSessionTimer();
    logout();
    notifyListeners();
  }

  void updateLastActivity() {
    _lastActivity = DateTime.now();
  }

  bool isSessionExpired() {
    if (_lastActivity == null) return true;
    return DateTime.now().difference(_lastActivity!) > _inactivityTimeout;
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
      // Save login time for session management
      await prefs.setString('login_time', DateTime.now().toIso8601String());
      debugPrint('Login time saved');
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
        _startSessionTimer();
        _lastActivity = DateTime.now();
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
        _startSessionTimer();
        _lastActivity = DateTime.now();
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
      await prefs.remove('login_time');
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }

    _currentUser = null;
    _token = null;
    _error = null;
    _stopSessionTimer();
    _lastActivity = null;
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

  @override
  void dispose() {
    _stopSessionTimer();
    super.dispose();
  }
}
