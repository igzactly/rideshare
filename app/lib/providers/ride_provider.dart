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

      print('Loading user rides...');
      final rides = await ApiService.getUserRides(token);
      print('Loaded ${rides.length} rides');
      
      // Log ride details for debugging
      for (final ride in rides) {
        print('Ride: ${ride.id} - Status: ${ride.status} - Type: ${ride.type} - Pickup: ${ride.pickupAddress}');
      }
      
      _userRides = rides;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading user rides: $e');
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

      print('Searching rides with params: $searchParams');
      final rides = await ApiService.searchRides(searchParams, token);
      print('Search returned ${rides.length} rides');
      
      _availableRides = rides;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error searching rides: $e');
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

      if (response['_id'] != null || response['id'] != null) {
        final newRide = Ride.fromJson(response);
        _userRides.add(newRide);
        _currentRide = newRide;
        // Also add to available rides if it's a driver ride
        if (newRide.type == RideType.driver) {
          _availableRides.add(newRide);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['detail'] ?? 'Failed to create ride';
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

  Future<bool> acceptRide(String rideId, String token, String passengerId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.acceptRide(rideId, token, passengerId);

      if (response['message'] != null && response['message'].contains('accepted')) {
        // Ride was accepted successfully
        // Update the ride in the available rides list
        final rideIndex = _availableRides.indexWhere((ride) => ride.id == rideId);
        if (rideIndex != -1) {
          _availableRides[rideIndex] = _availableRides[rideIndex].copyWith(
            status: RideStatus.accepted,
            passengerId: passengerId,
          );
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['detail'] ?? 'Failed to accept ride';
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

      if (response['message'] != null && response['message'].contains('updated')) {
        // Status was updated successfully
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['detail'] ?? 'Failed to update ride status';
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

  Future<bool> deleteRide(String rideId, String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.deleteRide(rideId, token);

      if (response['message'] != null && response['message'].contains('deleted')) {
        // Ride was deleted successfully
        _userRides.removeWhere((ride) => ride.id == rideId);
        if (_currentRide?.id == rideId) {
          _currentRide = null;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['detail'] ?? 'Failed to delete ride';
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

  Future<void> refreshUserRides(String token) async {
    await loadUserRides(token);
  }
}
