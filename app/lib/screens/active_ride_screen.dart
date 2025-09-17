import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';

import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../models/ride.dart';
import '../services/api_service.dart';
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
  List<Map<String, dynamic>> _participantsLocations = [];
  Timer? _participantsLocationTimer;
  late RideStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.ride.status;
    _initializeLocationTracking();
    _startStatusPolling();
    _startParticipantsLocationPolling();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _statusTimer?.cancel();
    _participantsLocationTimer?.cancel();
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
      
      // Send initial location update
      await _sendLocationUpdate(position);
      
      // Update location every 10 seconds
      _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          setState(() {
            _currentPosition = position;
          });
          
          // Send location update to backend
          await _sendLocationUpdate(position);
        } catch (e) {
          debugPrint('Error updating location: $e');
        }
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _sendLocationUpdate(Position position) async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.token != null) {
        await ApiService.updateDriverLocation(
          position.latitude,
          position.longitude,
          widget.ride.id,
          authProvider.token!,
        );
      }
    } catch (e) {
      debugPrint('Error sending location update: $e');
    }
  }

  void _startParticipantsLocationPolling() {
    // Poll participants' locations every 15 seconds
    _participantsLocationTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _fetchParticipantsLocations();
    });
    
    // Initial fetch
    _fetchParticipantsLocations();
  }

  Future<void> _fetchParticipantsLocations() async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.token != null) {
        final locations = await ApiService.getRideParticipantsLocations(
          widget.ride.id,
          authProvider.token!,
        );
        
        if (mounted) {
          setState(() {
            _participantsLocations = locations;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching participants locations: $e');
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
          _convertStatusToApi(newStatus),
          authProvider.token!,
        );
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ride status updated to ${newStatus.name}'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _status = newStatus;
          });
          
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
        return 'Waiting for passenger requests';
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
                    color: _getStatusColor(_status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getStatusText(_status),
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
    
    final currentStep = _status == RideStatus.pending ? 0 :
                       _status == RideStatus.accepted ? 1 :
                       _status == RideStatus.inProgress ? 2 :
                       _status == RideStatus.completed ? 3 : 0;

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
                color: isCompleted ? AppTheme.primaryPurple : Colors.grey[300],
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
                  color: isCompleted ? AppTheme.primaryPurple : Colors.grey[600],
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
            _buildInfoRow('Price', '£${widget.ride.price.toStringAsFixed(2)}'),
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

  Widget _buildLiveLocationCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppTheme.primaryPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_currentPosition != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentPosition != null) ...[
              _buildLocationRow(
                'Current Location',
                '${_currentPosition?.latitude.toStringAsFixed(6) ?? '0.000000'}, ${_currentPosition?.longitude.toStringAsFixed(6) ?? '0.000000'}',
              ),
              const SizedBox(height: 8),
              _buildLocationRow(
                'Accuracy',
                '${_currentPosition?.accuracy.toStringAsFixed(1) ?? '0.0'} meters',
              ),
              const SizedBox(height: 8),
              _buildLocationRow(
                'Last Updated',
                DateTime.now().toString().substring(11, 19),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
                ),
                child: const Text(
                  'Your location is being shared with passengers in real-time',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              _buildLiveLocationMap(),
            ] else ...[
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Getting your location...'),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Please ensure location permissions are enabled',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsLocationCard() {
    if (_participantsLocations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.people,
                  color: AppTheme.primaryPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Other Participants',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_participantsLocations.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._participantsLocations.map((location) {
              final coordinates = location['coordinates'] as List?;
              final userId = location['user_id'];
              final timestamp = location['timestamp'];
              
              if (coordinates == null || coordinates.length < 2) {
                return const SizedBox.shrink();
              }
              
              final lat = coordinates[1] as double;
              final lng = coordinates[0] as double;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.primaryPurple,
                      child: Text(
                        userId.toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
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
                          Text(
                            'User ${userId.toString().substring(0, 8)}...',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (timestamp != null)
                      Text(
                        DateTime.parse(timestamp).toString().substring(11, 19),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
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
              label: const Text('Chat with Passenger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
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
                foregroundColor: AppTheme.primaryPurple,
                side: const BorderSide(color: AppTheme.primaryPurple),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Payment Button (when ride is completed)
          if (widget.ride.status == RideStatus.completed)
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
                label: const Text('Complete Ride & Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          
          // Status Update Buttons
          if (_status == RideStatus.accepted)
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
          
          if (_status == RideStatus.inProgress)
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
                    : const Text('Finish Ride'),
              ),
            ),

          
          if (_status == RideStatus.pending)
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

  Widget _buildLiveLocationMap() {
    final LatLng center = _currentPosition != null
        ? LatLng(_currentPosition?.latitude ?? 0.0, _currentPosition?.longitude ?? 0.0)
        : (widget.ride.pickupLocation.latitude != 0.0 || widget.ride.pickupLocation.longitude != 0.0)
            ? widget.ride.pickupLocation
            : const LatLng(51.5074, -0.1278);

    final List<Marker> markers = [];
    if (_currentPosition != null) {
      markers.add(
        Marker(
          width: 40,
          height: 40,
          point: LatLng(_currentPosition?.latitude ?? 0.0, _currentPosition?.longitude ?? 0.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.4), blurRadius: 6, spreadRadius: 1),
              ],
            ),
            child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.rideshare_app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Ride'),
        backgroundColor: AppTheme.primaryPurple,
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
            _buildLiveLocationCard(),
            _buildParticipantsLocationCard(),
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
