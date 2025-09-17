import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class LocationProvider extends ChangeNotifier {
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  String _pickupAddress = '';
  String _dropoffAddress = '';
  bool _isLoading = false;
  String? _error;
  bool _locationPermissionGranted = false;

  LatLng? get currentLocation => _currentLocation;
  LatLng? get pickupLocation => _pickupLocation;
  LatLng? get dropoffLocation => _dropoffLocation;
  String get pickupAddress => _pickupAddress;
  String get dropoffAddress => _dropoffAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get locationPermissionGranted => _locationPermissionGranted;

  LocationProvider() {
    _checkLocationPermission();
  }

  Future<void> initializeLocation() async {
    await _checkLocationPermission();
    if (_locationPermissionGranted) {
      await getCurrentLocation();
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        _locationPermissionGranted =
            requestedPermission == LocationPermission.whileInUse ||
                requestedPermission == LocationPermission.always;
      } else {
        _locationPermissionGranted =
            permission == LocationPermission.whileInUse ||
                permission == LocationPermission.always;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to check location permission: $e';
      notifyListeners();
    }
  }

  Future<void> getCurrentLocation() async {
    if (!_locationPermissionGranted) {
      await _checkLocationPermission();
      if (!_locationPermissionGranted) {
        _error = 'Location permission not granted';
        notifyListeners();
        return;
      }
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentLocation = LatLng(position.latitude, position.longitude);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to get current location: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPickupLocation(LatLng location, String address) async {
    _pickupLocation = location;
    _pickupAddress = address;
    notifyListeners();
  }

  Future<void> setDropoffLocation(LatLng location, String address) async {
    _dropoffLocation = location;
    _dropoffAddress = address;
    notifyListeners();
  }

  Future<void> updateLocationToServer(String token, {String? rideId}) async {
    if (_currentLocation == null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final locationData = {
        'coordinates': [_currentLocation?.latitude ?? 0.0, _currentLocation?.longitude ?? 0.0],
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': 10.0, // Default accuracy
        'speed': 0.0, // Default speed
        'heading': 0.0, // Default heading
        if (rideId != null) 'ride_id': rideId,
      };

      final response = await ApiService.updateLocation(locationData, token);

      if (response['success'] != true) {
        _error = response['message'] ?? 'Failed to update location on server';
      }
    } catch (e) {
      _error = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startLiveTracking(String rideId, String token) async {
    if (!_locationPermissionGranted) {
      await _checkLocationPermission();
      if (!_locationPermissionGranted) {
        _error = 'Location permission not granted';
        notifyListeners();
        return;
      }
    }

    try {
      // Start live tracking on server
      final response = await ApiService.startLiveTracking(rideId, token);
      if (response['success'] != true) {
        _error = response['message'] ?? 'Failed to start live tracking';
        notifyListeners();
        return;
      }

      // Get initial location
      await getCurrentLocation();

      // Start periodic location updates with ride context
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Update every 5 meters for live tracking
        ),
      ).listen(
        (Position position) {
          _currentLocation = LatLng(position.latitude, position.longitude);
          notifyListeners();

          // Update server with new location including ride context
          updateLocationToServer(token, rideId: rideId);
        },
        onError: (e) {
          _error = 'Live tracking error: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Failed to start live tracking: $e';
      notifyListeners();
    }
  }

  Future<void> stopLiveTracking(String rideId, String token) async {
    try {
      final response = await ApiService.stopLiveTracking(rideId, token);
      if (response['success'] != true) {
        _error = response['message'] ?? 'Failed to stop live tracking';
        notifyListeners();
        return;
      }
    } catch (e) {
      _error = 'Failed to stop live tracking: $e';
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getLiveTrackingStatus(String rideId, String token) async {
    try {
      final response = await ApiService.getLiveTrackingStatus(rideId, token);
      if (response['success'] == true) {
        return response;
      } else {
        _error = response['message'] ?? 'Failed to get tracking status';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Failed to get tracking status: $e';
      notifyListeners();
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyDrivers(String token) async {
    if (_currentLocation == null) return [];

    try {
      return await ApiService.getNearbyDrivers(
        _currentLocation?.latitude ?? 0.0,
        _currentLocation?.longitude ?? 0.0,
        5.0, // 5km radius
        token,
      );
    } catch (e) {
      _error = 'Failed to get nearby drivers: $e';
      notifyListeners();
      return [];
    }
  }

  Future<void> startLocationUpdates(String token) async {
    if (!_locationPermissionGranted) {
      await _checkLocationPermission();
      if (!_locationPermissionGranted) {
        _error = 'Location permission not granted';
        notifyListeners();
        return;
      }
    }

    try {
      // Get initial location
      await getCurrentLocation();

      // Start periodic location updates
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) {
          _currentLocation = LatLng(position.latitude, position.longitude);
          notifyListeners();

          // Update server with new location
          updateLocationToServer(token);
        },
        onError: (e) {
          _error = 'Location stream error: $e';
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Failed to start location updates: $e';
      notifyListeners();
    }
  }

  double? calculateDistance(LatLng? from, LatLng? to) {
    if (from == null || to == null) return null;

    try {
      return Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
    } catch (e) {
      return null;
    }
  }

  double? getDistanceToPickup() {
    if (_currentLocation == null || _pickupLocation == null) return null;
    return calculateDistance(_currentLocation, _pickupLocation);
  }

  double? getDistanceToDropoff() {
    if (_currentLocation == null || _dropoffLocation == null) return null;
    return calculateDistance(_currentLocation, _dropoffLocation);
  }

  double? getTotalRideDistance() {
    if (_pickupLocation == null || _dropoffLocation == null) return null;
    return calculateDistance(_pickupLocation, _dropoffLocation);
  }

  void clearLocations() {
    _pickupLocation = null;
    _dropoffLocation = null;
    _pickupAddress = '';
    _dropoffAddress = '';
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  bool get hasValidRoute => _pickupLocation != null && _dropoffLocation != null;

  @override
  void dispose() {
    // Stop location updates if any
    super.dispose();
  }
}
