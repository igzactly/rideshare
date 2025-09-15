import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../models/ride.dart';
import '../middleware/api_session_middleware.dart';

class ApiService {
  static const String _baseUrl = 'http://158.158.41.106:8000';
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  static Map<String, String> _getAuthHeaders(String token) {
    return {
      ..._headers,
      'Authorization': 'Bearer $token',
    };
  }

  // Authentication endpoints
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Login failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Registration failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> updates,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/profile'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Profile update failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/validate'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return {'valid': true};
      } else {
        return {'valid': false};
      }
    } catch (e) {
      return {'valid': false, 'error': e.toString()};
    }
  }

  // Ride endpoints
  static Future<Map<String, dynamic>> createRide(
    Map<String, dynamic> rideData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rides'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(rideData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Ride creation failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<List<Ride>> searchRides(
    Map<String, dynamic> searchParams,
    String token,
  ) async {
    try {
      print('API Service: Searching rides with params: $searchParams');
      print('API Service: Using base URL: $_baseUrl');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/rides/find'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(searchParams),
      );

      print('API Service: Response status: ${response.statusCode}');
      print('API Service: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API Service: Decoded data: $data');
        
        final rides = (data['rides'] as List)
            .map((rideJson) => Ride.fromJson(rideJson))
            .toList();
        
        print('API Service: Parsed ${rides.length} rides');
        return rides;
      } else {
        print('API Service: Error response: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('API Service: Exception during search: $e');
      return [];
    }
  }

  static Future<List<Ride>> getUserRides(String token) async {
    try {
      // First get the current user info to determine ride types
      final userResponse = await http.get(
        Uri.parse('$_baseUrl/auth/validate'),
        headers: _getAuthHeaders(token),
      );

      String? currentUserId;
      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        currentUserId = userData['user_id'];
      }

      // Use the my_rides endpoint which gets all rides for the current user
      final response = await http.get(
        Uri.parse('$_baseUrl/rides/my_rides'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // The response is a direct list of rides
        final rides = (data as List)
            .map((rideJson) {
              final ride = Ride.fromJson(rideJson);
              // Determine ride type based on current user
              if (currentUserId != null) {
                if (rideJson['driver_id'] == currentUserId) {
                  return ride.copyWith(type: RideType.driver);
                } else {
                  return ride.copyWith(type: RideType.passenger);
                }
              }
              return ride;
            })
            .toList();
        print('Successfully loaded ${rides.length} rides from my_rides endpoint');
        return rides;
      } else {
        print('Failed to get user rides: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting user rides: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> acceptRide(
    String rideId,
    String token,
    String passengerId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rides/$rideId/accept'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({
          'passenger_id': passengerId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to accept ride: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> updateRideStatus(
    String rideId,
    String status,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/rides/$rideId/status'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to update ride status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteRide(
    String rideId,
    String token,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/rides/$rideId'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to delete ride: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Driver endpoints
  static Future<Map<String, dynamic>> createDriverRoute(
    Map<String, dynamic> routeData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/driver/routes'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(routeData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Route creation failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getDriverRoutes(
      String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/driver/routes'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['routes']);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Location updates
  static Future<Map<String, dynamic>> updateLocation(
    Map<String, dynamic> locationData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/location/update'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(locationData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Location update failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Live location tracking
  static Future<Map<String, dynamic>> startLiveTracking(
    String rideId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/location/live-tracking/start'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({'ride_id': rideId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to start live tracking: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> stopLiveTracking(
    String rideId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/location/live-tracking/stop'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({'ride_id': rideId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to stop live tracking: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getLiveTrackingStatus(
    String rideId,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/location/live-tracking/$rideId/status'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to get tracking status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getNearbyDrivers(
    double latitude,
    double longitude,
    double radiusKm,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/location/nearby-drivers?latitude=$latitude&longitude=$longitude&radius_km=$radiusKm'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Scheduled Rides
  static Future<Map<String, dynamic>> createScheduledRide(
    Map<String, dynamic> rideData,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/scheduled-rides'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(rideData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Scheduled ride creation failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getScheduledRides(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/scheduled-rides'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Notifications
  static Future<List<Map<String, dynamic>>> getNotifications(
    String token, {
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      final url = '$_baseUrl/notifications?limit=$limit&unread_only=$unreadOnly';
      final response = await http.get(
        Uri.parse(url),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(
    String notificationId,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/notifications/$notificationId/read'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to mark notification as read: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<int> getUnreadNotificationCount(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications/unread-count'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread_count'] ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }

  // Pricing and Earnings
  static Future<Map<String, dynamic>> estimateRidePrice(
    List<double> pickupCoords,
    List<double> dropoffCoords,
    String rideType,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/pricing/estimate'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({
          'pickup_coords': pickupCoords,
          'dropoff_coords': dropoffCoords,
          'ride_type': rideType,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Price estimation failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getDriverEarnings(
    String token, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      String url = '$_baseUrl/pricing/earnings';
      List<String> params = [];
      
      if (startDate != null) {
        params.add('start_date=${startDate.toIso8601String()}');
      }
      if (endDate != null) {
        params.add('end_date=${endDate.toIso8601String()}');
      }
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // Ride Preferences
  static Future<Map<String, dynamic>> getUserPreferences(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/preferences'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to get preferences: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> updateUserPreferences(
    Map<String, dynamic> preferences,
    String token,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/preferences'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(preferences),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to update preferences: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Analytics
  static Future<Map<String, dynamic>> getAnalyticsDashboard(
    String token, {
    String period = 'month',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analytics/dashboard?period=$period'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to get analytics: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getEnvironmentalAnalytics(
    String token, {
    String period = 'month',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/analytics/environmental?period=$period'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to get environmental analytics: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Multi-passenger rides
  static Future<Map<String, dynamic>> addPassengerToRide(
    String rideId,
    String passengerId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rides/$rideId/add-passenger'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({'passenger_id': passengerId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to add passenger: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> cancelRide(
    String rideId,
    String cancellationReason,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rides/$rideId/cancel'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({'cancellation_reason': cancellationReason}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to cancel ride: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}
