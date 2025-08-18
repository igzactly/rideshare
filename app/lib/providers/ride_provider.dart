import 'package:flutter/material.dart';
import '../models/ride.dart';
import '../services/api_service.dart';

class RideProvider extends ChangeNotifier {
  List<Ride> _userRides = [];
  List<Ride> _availableRides = [];
  Ride? _currentRide;
  bool _isLoading = false;
  String? _error;

  List<Ride> get userRides => _userRides;
  List<Ride> get availableRides => _availableRides;
  Ride? get currentRide => _currentRide;
  bool get isLoading => _isLoading;
  String? get error => _error;

  RideProvider() {
    // Initialize provider
  }

  Future<void> loadUserRides(String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final rides = await ApiService.getUserRides(token);
      _userRides = rides;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load rides: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchRides(
    Map<String, dynamic> searchParams,
    String token,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final rides = await ApiService.searchRides(searchParams, token);
      _availableRides = rides;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to search rides: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRide(
    Map<String, dynamic> rideData,
    String token,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.createRide(rideData, token);

      if (response['success'] == true) {
        final newRide = Ride.fromJson(response['ride']);
        _userRides.add(newRide);
        _currentRide = newRide;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to create ride';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptRide(String rideId, String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.acceptRide(rideId, token);

      if (response['success'] == true) {
        final updatedRide = Ride.fromJson(response['ride']);

        // Update the ride in available rides
        final index = _availableRides.indexWhere((ride) => ride.id == rideId);
        if (index != -1) {
          _availableRides[index] = updatedRide;
        }

        // Add to user rides if not already there
        if (!_userRides.any((ride) => ride.id == rideId)) {
          _userRides.add(updatedRide);
        }

        _currentRide = updatedRide;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to accept ride';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRideStatus(
    String rideId,
    String status,
    String token,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.updateRideStatus(rideId, status, token);

      if (response['success'] == true) {
        final updatedRide = Ride.fromJson(response['ride']);

        // Update ride in user rides
        final userRideIndex =
            _userRides.indexWhere((ride) => ride.id == rideId);
        if (userRideIndex != -1) {
          _userRides[userRideIndex] = updatedRide;
        }

        // Update ride in available rides
        final availableRideIndex =
            _availableRides.indexWhere((ride) => ride.id == rideId);
        if (availableRideIndex != -1) {
          _availableRides[availableRideIndex] = updatedRide;
        }

        // Update current ride if it's the same
        if (_currentRide?.id == rideId) {
          _currentRide = updatedRide;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to update ride status';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void setCurrentRide(Ride? ride) {
    _currentRide = ride;
    notifyListeners();
  }

  void clearCurrentRide() {
    _currentRide = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearAvailableRides() {
    _availableRides.clear();
    notifyListeners();
  }

  Ride? getRideById(String rideId) {
    final userRide = _userRides.where((ride) => ride.id == rideId).firstOrNull;
    if (userRide != null) return userRide;

    final availableRide =
        _availableRides.where((ride) => ride.id == rideId).firstOrNull;
    if (availableRide != null) return availableRide;

    return _currentRide?.id == rideId ? _currentRide : null;
  }

  List<Ride> getRidesByStatus(RideStatus status) {
    return _userRides.where((ride) => ride.status == status).toList();
  }

  List<Ride> getRidesByType(RideType type) {
    return _userRides.where((ride) => ride.type == type).toList();
  }
}
