import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../utils/theme.dart';
import '../services/api_service.dart';

class LiveTrackingWidget extends StatefulWidget {
  final String rideId;
  final String token;
  final bool isDriver;
  final LatLng? initialLocation;

  const LiveTrackingWidget({
    super.key,
    required this.rideId,
    required this.token,
    required this.isDriver,
    this.initialLocation,
  });

  @override
  State<LiveTrackingWidget> createState() => _LiveTrackingWidgetState();
}

class _LiveTrackingWidgetState extends State<LiveTrackingWidget> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _driverLocation;
  Timer? _locationTimer;
  Timer? _trackingTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _trackingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      // Get initial location
      await _getCurrentLocation();
      
      // Start periodic location updates
      _startLocationUpdates();
      
      // Start tracking driver's location
      _startTrackingDriver();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize tracking: $e';
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _error = 'Location permissions are denied';
            });
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error = 'Location permissions are permanently denied. Please enable in settings.';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _error = null; // Clear any previous errors
        });
      }
      
      // Center map on current location
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 15.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to get location: $e';
        });
      }
      print('Error getting current location: $e');
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _getCurrentLocation();
      
      // Update location on server
      if (_currentLocation != null) {
        try {
          final locationData = {
            'coordinates': [_currentLocation!.longitude, _currentLocation!.latitude],
            'timestamp': DateTime.now().toIso8601String(),
            'accuracy': 10.0,
            'speed': 0.0,
            'heading': 0.0,
            'ride_id': widget.rideId,
          };
          
          await ApiService.updateLocation(locationData, widget.token);
        } catch (e) {
          print('Error updating location: $e');
        }
      }
    });
  }

  void _startTrackingDriver() {
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final participants = await ApiService.getRideParticipantsLocations(widget.rideId, widget.token);
        
        for (final participant in participants) {
          // Look for driver location
          if (participant['location'] != null) {
            final location = participant['location'];
            final coords = location['coordinates'] as List;
            
            if (mounted) {
              setState(() {
                _driverLocation = LatLng(coords[1], coords[0]); // [lng, lat] to LatLng
              });
            }
            print('Updated driver location: ${_driverLocation}');
            break;
          }
        }
      } catch (e) {
        print('Error getting driver location: $e');
      }
    });
  }

  void _zoomToCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16.0);
    }
  }

  void _zoomToShowBothLocations() {
    if (_currentLocation != null && _driverLocation != null) {
      final bounds = LatLngBounds.fromPoints([_currentLocation!, _driverLocation!]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
    } else if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorColor),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppTheme.errorColor, size: 32),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _error = null;
                    });
                  }
                  _initializeTracking();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final center = _currentLocation ?? widget.initialLocation ?? const LatLng(51.5074, -0.1278);
    final markers = <Marker>[];

    // Add current user marker (Passenger)
    if (_currentLocation != null) {
      markers.add(
        Marker(
          width: 60,
          height: 80,
          point: _currentLocation!,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Add driver marker
    if (_driverLocation != null) {
      markers.add(
        Marker(
          width: 60,
          height: 80,
          point: _driverLocation!,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_taxi,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DRIVER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live Tracking',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_driverLocation != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TRACKING',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Zoom to current location button
                    GestureDetector(
                      onTap: _zoomToCurrentLocation,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: AppTheme.primaryBlue,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Zoom to show both locations button
                    GestureDetector(
                      onTap: _zoomToShowBothLocations,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.zoom_out_map,
                          color: AppTheme.primaryPurple,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15.0,
                  minZoom: 10.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rideshare.passenger',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
