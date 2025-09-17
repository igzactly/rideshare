import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../utils/theme.dart';
import '../models/ride.dart';
import '../widgets/driver_info_widget.dart';
import '../widgets/live_tracking_widget.dart';

class ActiveRideScreen extends StatefulWidget {
  final Ride ride;

  const ActiveRideScreen({super.key, required this.ride});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  late RideStatus _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _status = widget.ride.status;
  }

  Future<void> _updateRideStatus(RideStatus newStatus) async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();

    if (authProvider.token == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await rideProvider.updateRideStatus(
        widget.ride.id,
        _convertStatusToApi(newStatus),
        authProvider.token!,
      );

      if (success) {
        setState(() {
          _status = newStatus;
          _isLoading = false;
        });

        if (newStatus == RideStatus.completed && mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ride completed! Thank you for traveling with us.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _convertStatusToApi(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return 'active';
      case RideStatus.pending:
        return 'pending';
      case RideStatus.accepted:
        return 'accepted';
      case RideStatus.inProgress:
        return 'in_progress';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.cancelled:
        return 'cancelled';
    }
  }

  String _getStatusText(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return 'Available';
      case RideStatus.pending:
        return 'Awaiting driver approval';
      case RideStatus.accepted:
        return 'Driver accepted - Ready to start';
      case RideStatus.inProgress:
        return 'Ride in progress';
      case RideStatus.completed:
        return 'Ride completed';
      case RideStatus.cancelled:
        return 'Ride cancelled';
    }
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return AppTheme.primaryBlue;
      case RideStatus.pending:
        return AppTheme.warningColor;
      case RideStatus.accepted:
        return AppTheme.primaryBlue;
      case RideStatus.inProgress:
        return AppTheme.successColor;
      case RideStatus.completed:
        return AppTheme.successColor;
      case RideStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Ride Details'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildRideInfo(),
            const SizedBox(height: 20),
            _buildDriverInfo(),
            const SizedBox(height: 20),
            _buildLiveTracking(),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getStatusColor(_status).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            _getStatusIcon(_status),
            size: 48,
            color: _getStatusColor(_status),
          ),
          const SizedBox(height: 12),
          Text(
            _getStatusText(_status),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(_status),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusDescription(_status),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRideInfo() {
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
          const Text(
            'Ride Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('From', widget.ride.pickupAddress, Icons.location_on, AppTheme.primaryBlue),
          const SizedBox(height: 12),
          _buildInfoRow('To', widget.ride.dropoffAddress, Icons.flag, AppTheme.primaryPink),
          const SizedBox(height: 12),
          _buildInfoRow('Pickup Time', widget.ride.pickupTime.toString().substring(0, 16), Icons.schedule, AppTheme.textSecondary),
          const SizedBox(height: 12),
          _buildInfoRow('Price', '£${widget.ride.price.toStringAsFixed(2)}', Icons.payment, AppTheme.primaryPurple),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverInfo() {
    // Only show driver info if ride has been accepted or is in progress
    if (_status == RideStatus.accepted || _status == RideStatus.inProgress || _status == RideStatus.completed) {
      return DriverInfoWidget(
        driverId: widget.ride.driverId,
        showCompact: false,
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildLiveTracking() {
    // Only show live tracking for accepted and in-progress rides
    if (_status == RideStatus.accepted || _status == RideStatus.inProgress) {
      final authProvider = context.read<AuthProvider>();
      return LiveTrackingWidget(
        rideId: widget.ride.id,
        token: authProvider.token ?? '',
        isDriver: false,
        initialLocation: widget.ride.pickupLocation,
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildActionButtons() {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.id ?? '';
    final isPassenger = widget.ride.passengerId == currentUserId;

    if (!isPassenger) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Status-specific actions for passengers
        if (_status == RideStatus.pending)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warningColor),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_empty, color: AppTheme.warningColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Awaiting Driver Approval',
                        style: TextStyle(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your ride request is pending. The driver will respond shortly.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_status == RideStatus.accepted)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _updateRideStatus(RideStatus.inProgress),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

        if (_status == RideStatus.inProgress)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _updateRideStatus(RideStatus.completed),
              icon: const Icon(Icons.check),
              label: const Text('Complete Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

        // Cancel button for pending rides
        if (_status == RideStatus.pending)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _updateRideStatus(RideStatus.cancelled),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel Request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getStatusIcon(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return Icons.event_available;
      case RideStatus.pending:
        return Icons.hourglass_empty;
      case RideStatus.accepted:
        return Icons.check_circle;
      case RideStatus.inProgress:
        return Icons.directions_car;
      case RideStatus.completed:
        return Icons.check_circle_outline;
      case RideStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusDescription(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return 'This ride is available for booking';
      case RideStatus.pending:
        return 'Waiting for the driver to accept your request';
      case RideStatus.accepted:
        return 'Driver has accepted your request. Ready to start!';
      case RideStatus.inProgress:
        return 'You are currently on this ride';
      case RideStatus.completed:
        return 'This ride has been completed successfully';
      case RideStatus.cancelled:
        return 'This ride has been cancelled';
    }
  }
}
