import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/theme.dart';

class DriverInfoWidget extends StatefulWidget {
  final String? driverId;
  final bool isCompact;

  const DriverInfoWidget({
    super.key,
    required this.driverId,
    this.isCompact = false,
  });

  @override
  State<DriverInfoWidget> createState() => _DriverInfoWidgetState();
}

class _DriverInfoWidgetState extends State<DriverInfoWidget> {
  User? _driver;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.driverId != null) {
      _loadDriverInfo();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDriverInfo() async {
    if (widget.driverId == null) return;

    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.token == null) return;

      final userData = await ApiService.getUserById(widget.driverId!, authProvider.token!);
      
      if (mounted) {
        if (userData != null) {
          setState(() {
            _driver = User.fromJson(userData);
            _isLoading = false;
            _error = null;
          });
        } else {
          setState(() {
            _driver = null;
            _isLoading = false;
            _error = 'Driver information not available';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _driver = null;
          _isLoading = false;
          _error = 'Failed to load driver info';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.driverId == null) {
      return widget.isCompact
          ? const SizedBox.shrink()
          : const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No driver assigned'),
              ),
            );
    }

    if (_isLoading) {
      return widget.isCompact
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Loading driver info...'),
                  ],
                ),
              ),
            );
    }

    if (_error != null || _driver == null) {
      return widget.isCompact
          ? const SizedBox.shrink()
          : Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(
                      _error ?? 'Driver information not available',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
    }

    if (widget.isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryPurple,
            child: Text(
              _driver?.name.isNotEmpty == true ? _driver!.name[0].toUpperCase() : 'D',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _driver?.name ?? 'Unknown Driver',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_driver?.isVerified == true) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.verified,
              size: 12,
              color: Colors.blue,
            ),
          ],
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car, color: AppTheme.primaryPurple),
                const SizedBox(width: 8),
                const Text(
                  'Driver Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryPurple,
                  child: Text(
                    _driver?.name.isNotEmpty == true ? _driver!.name[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _driver?.name ?? 'Unknown Driver',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_driver?.isVerified == true) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _driver!.phone.isNotEmpty ? _driver!.phone : 'Phone not provided',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      if (_driver?.isDriver == true) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'Verified Driver',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
