import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

class DebugSessionScreen extends StatefulWidget {
  const DebugSessionScreen({super.key});

  @override
  State<DebugSessionScreen> createState() => _DebugSessionScreenState();
}

class _DebugSessionScreenState extends State<DebugSessionScreen> {
  String _debugInfo = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    
    final storedToken = prefs.getString('auth_token');
    final storedUserData = prefs.getString('user_data');
    
    setState(() {
      _debugInfo = '''
AuthProvider State:
- isAuthenticated: ${authProvider.isAuthenticated}
- hasToken: ${authProvider.token != null}
- hasUser: ${authProvider.currentUser != null}
- user: ${authProvider.currentUser?.name ?? 'None'}

SharedPreferences:
- storedToken: ${storedToken != null ? 'Found (${storedToken.substring(0, 20)}...)' : 'Not found'}
- storedUserData: ${storedUserData != null ? 'Found' : 'Not found'}

Debug Actions:
- Clear session data
- Test token validation
- Reload auth state
''';
    });
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await _loadDebugInfo();
  }

  Future<void> _testTokenValidation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      try {
        // Test token validation by calling the API directly
        final response = await authProvider.validateToken();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Token validation result: $response'),
            backgroundColor: response ? Colors.green : Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Token validation error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No token to validate'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Debug'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _debugInfo,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear Session Data'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _testTokenValidation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Token Validation'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadDebugInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh Debug Info'),
            ),
          ],
        ),
      ),
    );
  }
}
