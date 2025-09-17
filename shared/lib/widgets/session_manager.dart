import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/session_expired_screen.dart';

class SessionManager extends StatefulWidget {
  final Widget child;
  
  const SessionManager({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> with WidgetsBindingObserver {
  bool _isSessionExpired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupSessionListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupSessionListener() {
    // Listen to auth provider changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.addListener(_onAuthChanged);
    });
  }

  void _onAuthChanged() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check if session expired
    if (!authProvider.isAuthenticated && !_isSessionExpired) {
      _isSessionExpired = true;
      _showSessionExpiredDialog();
    } else if (authProvider.isAuthenticated) {
      _isSessionExpired = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, check session validity
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.isSessionExpired()) {
        _showSessionExpiredDialog();
      } else if (authProvider.isAuthenticated) {
        // Update last activity when app resumes
        authProvider.updateLastActivity();
      }
    } else if (state == AppLifecycleState.paused) {
      // App went to background, update last activity
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        authProvider.updateLastActivity();
      }
    }
  }

  void _showSessionExpiredDialog() {
    if (!mounted) return;
    
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
              'Your session has expired due to inactivity or time limit. Please log in again to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _redirectToLogin();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _redirectToLogin() {
    if (!mounted) return;
    
    // Clear any existing routes and go to login
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Update last activity on any user interaction
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isAuthenticated) {
          authProvider.updateLastActivity();
        }
      },
      child: widget.child,
    );
  }
}

class SessionAwareWidget extends StatefulWidget {
  final Widget child;
  
  const SessionAwareWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<SessionAwareWidget> createState() => _SessionAwareWidgetState();
}

class _SessionAwareWidgetState extends State<SessionAwareWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // If not authenticated, show session expired screen
        if (!authProvider.isAuthenticated) {
          return const SessionExpiredScreen();
        }
        
        // If session expired, show session expired message
        if (authProvider.isSessionExpired()) {
          return const SessionExpiredScreen();
        }
        
        // Otherwise, show the child widget
        return widget.child;
      },
    );
  }
}

