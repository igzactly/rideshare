import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../utils/theme.dart';
import '../services/api_service.dart';

class LocationStatusWidget extends StatefulWidget {
  final String rideId;
  final String token;
  final bool isDriver;

  const LocationStatusWidget({
    super.key,
    required this.rideId,
    required this.token,
    required this.isDriver,
  });

  @override
  State<LocationStatusWidget> createState() => _LocationStatusWidgetState();
}

class _LocationStatusWidgetState extends State<LocationStatusWidget> {
  Position? _currentPosition;
  Position? _otherUserPosition;
  Timer? _locationTimer;
  String? _error;
  double? _distanceToOtherUser;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _updateLocation();
    });
    
    // Initial location update
    _updateLocation();
  }

  Future<void> _updateLocation() async {
    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
      });

      // Update location on server if driver
      if (widget.isDriver) {
        final locationData = {
          'coordinates': [position.longitude, position.latitude],
          'timestamp': DateTime.now().toIso8601String(),
          'accuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
          'ride_id': widget.rideId,
        };
        
        await ApiService.updateLocation(locationData, widget.token);
      }

      // Get other user's location
      await _getOtherUserLocation();
      
    } catch (e) {
      setState(() {
        _error = 'Location error: $e';
      });
    }
  }

  Future<void> _getOtherUserLocation() async {
    try {
      final participants = await ApiService.getRideParticipantsLocations(widget.rideId, widget.token);
      
      for (final participant in participants) {
        if (participant['location'] != null) {
          final location = participant['location'];
          final coords = location['coordinates'] as List;
          
          final otherPosition = Position(
            latitude: coords[1],
            longitude: coords[0],
            timestamp: DateTime.now(),
            accuracy: 10.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
          
          setState(() {
            _otherUserPosition = otherPosition;
          });
          
          // Calculate distance
          if (_currentPosition != null) {
            final distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              otherPosition.latitude,
              otherPosition.longitude,
            );
            
            setState(() {
              _distanceToOtherUser = distance / 1000; // Convert to km
            });
          }
          break;
        }
      }
    } catch (e) {
      print('Error getting other user location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.errorColor),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorColor, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppTheme.primaryPurple,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Location',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_currentPosition != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (_distanceToOtherUser != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  widget.isDriver ? Icons.person : Icons.local_taxi,
                  color: AppTheme.textSecondary,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isDriver 
                      ? 'Passenger: ${_distanceToOtherUser!.toStringAsFixed(1)}km away'
                      : 'Driver: ${_distanceToOtherUser!.toStringAsFixed(1)}km away',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          if (_currentPosition != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.my_location, color: AppTheme.textTertiary, size: 12),
                const SizedBox(width: 8),
                Text(
                  'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
