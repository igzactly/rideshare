import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride.dart';
import '../utils/theme.dart';
import 'payment_received_screen.dart';
import 'ride_completion_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final Ride ride;
  
  const RideDetailsScreen({
    super.key,
    required this.ride,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRideStatusCard(),
            const SizedBox(height: 16),
            _buildRideInfoCard(),
            const SizedBox(height: 16),
            _buildUserInfoCard(),
            const SizedBox(height: 16),
            _buildRideHistoryCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildRideStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.ride.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getStatusText(widget.ride.status),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _getProgressValue(widget.ride.status),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_car,
                  color: AppTheme.primaryPurple,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ride Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Ride ID', '#${widget.ride.id.substring(0, 8)}'),
            _buildInfoRow('Type', widget.ride.type.name.toUpperCase()),
            _buildInfoRow('Status', _getStatusText(widget.ride.status)),
            _buildInfoRow('Price', '£${widget.ride.price.toStringAsFixed(2)}'),
            _buildInfoRow('Created', _formatDateTime(widget.ride.createdAt)),
            _buildInfoRow('Updated', _formatDateTime(widget.ride.updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: AppTheme.primaryPink,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.ride.type == RideType.passenger ? 'Driver Info' : 'Passenger Info',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.ride.driverId != null) ...[
              _buildInfoRow('Driver ID', widget.ride.driverId!),
              _buildInfoRow('Driver Name', 'John Doe'), // TODO: Get from API
              _buildInfoRow('Driver Rating', '4.8 ⭐'),
            ],
            if (widget.ride.passengerId != null) ...[
              _buildInfoRow('Passenger ID', widget.ride.passengerId!),
              _buildInfoRow('Passenger Name', 'Jane Smith'), // TODO: Get from API
              _buildInfoRow('Passenger Rating', '4.9 ⭐'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRideHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: AppTheme.primaryOrange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ride History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              'Ride Created',
              _formatDateTime(widget.ride.createdAt),
              Icons.add_circle,
              Colors.green,
            ),
            if (widget.ride.status != RideStatus.pending)
              _buildTimelineItem(
                'Ride Accepted',
                _formatDateTime(widget.ride.updatedAt),
                Icons.check_circle,
                Colors.blue,
              ),
            if (widget.ride.status == RideStatus.inProgress)
              _buildTimelineItem(
                'Ride Started',
                _formatDateTime(widget.ride.updatedAt),
                Icons.play_circle,
                Colors.orange,
              ),
            if (widget.ride.status == RideStatus.completed)
              _buildTimelineItem(
                'Ride Completed',
                _formatDateTime(widget.ride.updatedAt),
                Icons.check_circle,
                Colors.green,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Payment Button (for passengers when ride is completed)
        if (widget.ride.type == RideType.passenger && widget.ride.status == RideStatus.completed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => RideCompletionScreen(ride: widget.ride),
                  ),
                );
              },
              icon: const Icon(Icons.payment),
              label: const Text('Pay Driver'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        
        // Payment Received Button (for drivers when ride is completed)
        if (widget.ride.type == RideType.driver && widget.ride.status == RideStatus.completed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaymentReceivedScreen(ride: widget.ride),
                  ),
                );
              },
              icon: const Icon(Icons.payment),
              label: const Text('Payment Received'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        
        if (widget.ride.status == RideStatus.pending)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _cancelRide(),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        
        if (widget.ride.status == RideStatus.accepted)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _startRide(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        
        if (widget.ride.status == RideStatus.inProgress)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _completeRide(),
              icon: const Icon(Icons.check),
              label: const Text('Complete Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        
        const SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _shareRideDetails(),
            icon: const Icon(Icons.share),
            label: const Text('Share Ride Details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryPurple,
              side: const BorderSide(color: AppTheme.primaryPurple),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return 'Active';
      case RideStatus.pending:
        return 'Pending';
      case RideStatus.accepted:
        return 'Accepted';
      case RideStatus.inProgress:
        return 'In Progress';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return AppTheme.primaryPurple;
      case RideStatus.pending:
        return Colors.orange;
      case RideStatus.accepted:
        return Colors.blue;
      case RideStatus.inProgress:
        return Colors.green;
      case RideStatus.completed:
        return Colors.green;
      case RideStatus.cancelled:
        return Colors.red;
    }
  }

  double _getProgressValue(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return 0.1;
      case RideStatus.pending:
        return 0.25;
      case RideStatus.accepted:
        return 0.5;
      case RideStatus.inProgress:
        return 0.75;
      case RideStatus.completed:
        return 1.0;
      case RideStatus.cancelled:
        return 0.0;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _cancelRide() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement cancel ride API call
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startRide() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement start ride API call
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride started successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeRide() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement complete ride API call
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _shareRideDetails() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share feature coming soon!'),
      ),
    );
  }
}
