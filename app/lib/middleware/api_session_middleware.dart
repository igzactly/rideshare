import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

class ApiSessionMiddleware {
  static Future<Map<String, dynamic>> handleApiCall(
    BuildContext context,
    Future<Map<String, dynamic>> Function() apiCall,
  ) async {
    try {
      final result = await apiCall();
      
      // Check if the API call failed due to authentication
      if (result['success'] == false && 
          (result['message']?.toString().toLowerCase().contains('login') == true ||
           result['message']?.toString().toLowerCase().contains('unauthorized') == true ||
           result['message']?.toString().toLowerCase().contains('token') == true)) {
        
        // Session expired, redirect to login
        _handleSessionExpiry(context);
        return {
          'success': false,
          'message': 'Session expired. Please log in again.',
          'session_expired': true,
        };
      }
      
      return result;
    } catch (e) {
      // Check if it's an authentication error
      if (e.toString().toLowerCase().contains('unauthorized') ||
          e.toString().toLowerCase().contains('401')) {
        _handleSessionExpiry(context);
        return {
          'success': false,
          'message': 'Session expired. Please log in again.',
          'session_expired': true,
        };
      }
      
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static void _handleSessionExpiry(BuildContext context) {
    // Clear the session
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.logout();
    
    // Show session expired dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Session Expired'),
              ],
            ),
            content: const Text(
              'Your session has expired. Please log in again to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _redirectToLogin(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _redirectToLogin(BuildContext context) {
    // Clear any existing routes and go to login
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}

// Extension to make API calls easier
extension ApiCallExtension on BuildContext {
  Future<Map<String, dynamic>> safeApiCall(
    Future<Map<String, dynamic>> Function() apiCall,
  ) async {
    return ApiSessionMiddleware.handleApiCall(this, apiCall);
  }
}
