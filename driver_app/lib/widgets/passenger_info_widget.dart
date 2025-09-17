import 'package:flutter/material.dart';
import '../models/user.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';

class PassengerInfoWidget extends StatefulWidget {
  final String? passengerId;
  final bool showCompact;

  const PassengerInfoWidget({
    super.key,
    required this.passengerId,
    this.showCompact = false,
  });

  @override
  State<PassengerInfoWidget> createState() => _PassengerInfoWidgetState();
}

class _PassengerInfoWidgetState extends State<PassengerInfoWidget> {
  User? _passenger;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.passengerId != null && widget.passengerId!.isNotEmpty) {
      _loadPassengerInfo();
    }
  }

  Future<void> _loadPassengerInfo() async {
    if (widget.passengerId == null || widget.passengerId!.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getUserById(widget.passengerId!, '');
      
      if (response['success'] != false && response['id'] != null) {
        setState(() {
          _passenger = User.fromJson(response);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load passenger information';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading passenger: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.passengerId == null || widget.passengerId!.isEmpty) {
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
              'No passenger requests yet',
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
              'Loading passenger information...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null || _passenger == null) {
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
                _error ?? 'Passenger information not available',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            IconButton(
              onPressed: _loadPassengerInfo,
              icon: const Icon(Icons.refresh, color: AppTheme.primaryPurple),
              iconSize: 20,
            ),
          ],
        ),
      );
    }

    if (widget.showCompact) {
      return _buildCompactPassengerInfo();
    } else {
      return _buildFullPassengerInfo();
    }
  }

  Widget _buildCompactPassengerInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppTheme.primaryPurple,
          child: Text(
            _passenger?.name.isNotEmpty == true ? _passenger!.name[0].toUpperCase() : 'P',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _passenger?.name ?? 'Unknown Passenger',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        if (_passenger?.isVerified == true) ...[
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

  Widget _buildFullPassengerInfo() {
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
              const Icon(Icons.person, color: AppTheme.primaryPurple),
              const SizedBox(width: 8),
              const Text(
                'Your Passenger',
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
                backgroundColor: AppTheme.primaryPurple,
                child: Text(
                  _passenger?.name.isNotEmpty == true ? _passenger!.name[0].toUpperCase() : 'P',
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
                          _passenger?.name ?? 'Unknown Passenger',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (_passenger?.isVerified == true) ...[
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
                      _passenger?.phone.isNotEmpty == true ? _passenger!.phone : 'Phone not provided',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 12,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Contact',
                                style: TextStyle(
                                  color: AppTheme.primaryBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Passenger',
                            style: TextStyle(
                              color: AppTheme.primaryPurple,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
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
