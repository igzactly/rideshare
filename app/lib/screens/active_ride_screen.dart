import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../models/ride.dart';
import '../utils/theme.dart';
import 'chat_screen.dart';
import 'ride_details_screen.dart';
import 'payment_received_screen.dart';
import 'ride_completion_screen.dart';

class ActiveRideScreen extends StatefulWidget {
  final Ride ride;
  
  const ActiveRideScreen({
    super.key,
    required this.ride,
  });

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  bool _isLoading = false;
  Position? _currentPosition;
  Timer? _locationTimer;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocationTracking() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
      
      // Update location every 10 seconds
      _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentPosition = position;
        });
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _startStatusPolling() {
    // Poll ride status every 30 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final rideProvider = context.read<RideProvider>();
      final authProvider = context.read<AuthProvider>();
      
      if (authProvider.token != null) {
        await rideProvider.loadUserRides(authProvider.token!);
      }
    });
  }

  Future<void> _updateRideStatus(RideStatus newStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rideProvider = context.read<RideProvider>();
      final authProvider = context.read<AuthProvider>();
      
      if (authProvider.token != null) {
        final success = await rideProvider.updateRideStatus(
          widget.ride.id,
          newStatus.name,
          authProvider.token!,
        );
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ride status updated to ${newStatus.name}'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to completion screen if ride is completed
          if (newStatus == RideStatus.completed) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => RideCompletionScreen(ride: widget.ride),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ride status: $e'),
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

  String _getStatusText(RideStatus status) {
    switch (status) {
      case RideStatus.pending:
        return 'Waiting for confirmation';
      case RideStatus.accepted:
        return 'Ride confirmed';
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

  Widget _buildStatusCard() {
    return Card(
      margin: const EdgeInsets.all(16),
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
            _buildProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = [
      'Ride Requested',
      'Ride Accepted',
      'Ride Started',
      'Ride Completed',
    ];
    
    final currentStep = widget.ride.status == RideStatus.pending ? 0 :
                       widget.ride.status == RideStatus.accepted ? 1 :
                       widget.ride.status == RideStatus.inProgress ? 2 :
                       widget.ride.status == RideStatus.completed ? 3 : 0;

    return Column(
      children: List.generate(steps.length, (index) {
        final isCompleted = index <= currentStep;
        final isCurrent = index == currentStep;
        
        return Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? AppTheme.primaryColor : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                steps[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  color: isCompleted ? AppTheme.primaryColor : Colors.grey[600],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildRideInfo() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ride Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('From', widget.ride.pickupAddress),
            const SizedBox(height: 8),
            _buildInfoRow('To', widget.ride.dropoffAddress),
            const SizedBox(height: 8),
            _buildInfoRow('Time', widget.ride.pickupTime.toString().substring(0, 16)),
            const SizedBox(height: 8),
            _buildInfoRow('Price', '\$${widget.ride.price.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow('Type', widget.ride.type.name.toUpperCase()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
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
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Chat Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(ride: widget.ride),
                  ),
                );
              },
              icon: const Icon(Icons.chat),
              label: Text('Chat with ${widget.ride.type == RideType.passenger ? 'Driver' : 'Passenger'}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Ride Details Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RideDetailsScreen(ride: widget.ride),
                  ),
                );
              },
              icon: const Icon(Icons.info),
              label: const Text('View Ride Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
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
                  backgroundColor: AppTheme.accentColor,
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
          
          // Status Update Buttons
          if (widget.ride.status == RideStatus.accepted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _updateRideStatus(RideStatus.inProgress),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Start Ride'),
              ),
            ),
          
          if (widget.ride.status == RideStatus.inProgress)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _updateRideStatus(RideStatus.completed),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Complete Ride'),
              ),
            ),
          
          if (widget.ride.status == RideStatus.pending)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _updateRideStatus(RideStatus.cancelled),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Cancel Ride'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Ride'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final rideProvider = context.read<RideProvider>();
              final authProvider = context.read<AuthProvider>();
              if (authProvider.token != null) {
                rideProvider.loadUserRides(authProvider.token!);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusCard(),
            _buildRideInfo(),
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
