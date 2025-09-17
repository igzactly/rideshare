import 'package:flutter/material.dart';
import '../models/ride.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_banner.dart';

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
      print('Using token: ${token.substring(0, 20)}...');
      
      final rides = await ApiService.searchRides(searchParams, token);
      print('Search returned ${rides.length} rides');
      
      // Log each ride for debugging
      for (final ride in rides) {
        print('Found ride: ${ride.id} - ${ride.pickupAddress} -> ${ride.dropoffAddress} - Status: ${ride.status}');
      }
      
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
      print('RideProvider: Received response: $response');

      if (response['_id'] != null || response['id'] != null) {
        print('RideProvider: Ride created successfully with ID: ${response['_id'] ?? response['id']}');
        try {
          final newRide = Ride.fromJson(response);
          print('RideProvider: Successfully parsed ride: ${newRide.id}');
          _userRides.add(newRide);
          _currentRide = newRide;
          // Add to available rides since all rides are driver rides
          _availableRides.add(newRide);
          _isLoading = false;
          notifyListeners();
          return true;
        } catch (e) {
          print('RideProvider: Error parsing ride from JSON: $e');
          print('RideProvider: Response data: $response');
          _error = 'Failed to parse ride data: $e';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        print('RideProvider: Failed to create ride - no ID in response: $response');
        _error = response['detail'] ?? response['message'] ?? 'Failed to create ride';
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

  Future<bool> requestRide(String rideId, String passengerId, String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.requestRide(rideId, passengerId, token);
      
      if (response['success'] == true) {
        // Refresh user rides to show the requested ride
        await loadUserRides(token);
        
        // Send notification to driver about new ride request
        try {
          // Find the ride to get pickup/dropoff addresses
          final ride = _userRides.firstWhere((r) => r.id == rideId);
          
          await NotificationService().showRideRequestNotification(
            passengerName: "Passenger", // This should be fetched from user data
            pickupAddress: ride.pickupAddress,
            dropoffAddress: ride.dropoffAddress,
            rideId: rideId,
          );
        } catch (e) {
          print('Error sending notification: $e');
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to request ride';
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

  Future<bool> acceptPassengerRequest(String rideId, String passengerId, String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.acceptPassengerRequest(rideId, passengerId, token);
      
      if (response['success'] == true) {
        // Refresh user rides to show the accepted ride
        await loadUserRides(token);
        
        // Send notification to passenger
        try {
          // Get driver name from current user (you might want to get this from API)
          final driverName = "Driver"; // This should be fetched from user data
          
          // Find the ride to get pickup/dropoff addresses
          final ride = _userRides.firstWhere((r) => r.id == rideId);
          
          await NotificationService().showRideAcceptedNotification(
            driverName: driverName,
            pickupAddress: ride.pickupAddress,
            dropoffAddress: ride.dropoffAddress,
            rideId: rideId,
          );
        } catch (e) {
          print('Error sending notification: $e');
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to accept passenger request';
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
        // Status was updated successfully - refresh the user rides
        await loadUserRides(token);
        
        // Send appropriate notifications based on status
        try {
          final ride = _userRides.firstWhere((r) => r.id == rideId);
          
          if (status == 'in_progress') {
            // Notify passenger that ride has started
            await NotificationService().showRideStartedNotification(
              driverName: "Driver", // This should be fetched from user data
              rideId: rideId,
            );
          } else if (status == 'completed') {
            // Notify passenger that ride is completed
            await NotificationService().showRideCompletedNotification(
              driverName: "Driver", // This should be fetched from user data
              rideId: rideId,
            );
          }
        } catch (e) {
          print('Error sending notification: $e');
        }
        
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
