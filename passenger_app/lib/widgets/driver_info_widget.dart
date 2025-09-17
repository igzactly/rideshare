import 'package:flutter/material.dart';
import '../models/user.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';

class DriverInfoWidget extends StatefulWidget {
  final String? driverId;
  final bool showCompact;

  const DriverInfoWidget({
    super.key,
    required this.driverId,
    this.showCompact = false,
  });

  @override
  State<DriverInfoWidget> createState() => _DriverInfoWidgetState();
}

class _DriverInfoWidgetState extends State<DriverInfoWidget> {
  User? _driver;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.driverId != null && widget.driverId!.isNotEmpty) {
      _loadDriverInfo();
    }
  }

  Future<void> _loadDriverInfo() async {
    if (widget.driverId == null || widget.driverId!.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Note: You'll need to implement getUserById in ApiService if it doesn't exist
      final response = await ApiService.getUserById(widget.driverId!, '');
      
      if (response['success'] != false && response['id'] != null) {
        setState(() {
          _driver = User.fromJson(response);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load driver information';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading driver: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.driverId == null || widget.driverId!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkDivider),
        ),
        child: const Row(
          children: [
            Icon(Icons.person_outline, color: AppTheme.textSecondary),
            SizedBox(width: 12),
            Text(
              'No driver assigned yet',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkDivider),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Loading driver information...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null || _driver == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkDivider),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error ?? 'Driver information not available',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            IconButton(
              onPressed: _loadDriverInfo,
              icon: const Icon(Icons.refresh, color: AppTheme.primaryBlue),
              iconSize: 20,
            ),
          ],
        ),
      );
    }

    if (widget.showCompact) {
      return _buildCompactDriverInfo();
    } else {
      return _buildFullDriverInfo();
    }
  }

  Widget _buildCompactDriverInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppTheme.primaryBlue,
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
            color: AppTheme.textPrimary,
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

  Widget _buildFullDriverInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_taxi, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Your Driver',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryBlue,
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
                            color: AppTheme.textPrimary,
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
                      _driver?.phone.isNotEmpty == true ? _driver!.phone : 'Phone not provided',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (_driver?.isDriver == true) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Verified Driver',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
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
    );
  }
}