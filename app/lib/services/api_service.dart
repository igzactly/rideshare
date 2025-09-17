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
      print('API Service: Creating ride with data: $rideData');
      print('API Service: Using token: ${token.substring(0, 20)}...');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/rides'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(rideData),
      );

      print('API Service: Ride creation response status: ${response.statusCode}');
      print('API Service: Ride creation response body: ${response.body}');

      if (response.statusCode == 201) {
        final result = jsonDecode(response.body);
        print('API Service: Ride created successfully: $result');
        return result;
      } else {
        print('API Service: Ride creation failed: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': 'Ride creation failed: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      print('API Service: Exception during ride creation: $e');
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
        
        try {
          final rides = (data['rides'] as List)
              .map((rideJson) {
                try {
                  return Ride.fromJson(rideJson);
                } catch (e) {
                  print('API Service: Error parsing ride: $e');
                  print('API Service: Problematic ride data: $rideJson');
                  return null;
                }
              })
              .where((ride) => ride != null)
              .cast<Ride>()
              .toList();
          
          print('API Service: Successfully parsed ${rides.length} rides');
          return rides;
        } catch (e) {
          print('API Service: Error parsing rides list: $e');
          return [];
        }
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
        print('Got user_id from validate: $currentUserId');
      } else {
        print('Failed to validate token: ${userResponse.statusCode} - ${userResponse.body}');
        return [];
      }

      // Use the my_rides endpoint with user_id parameter as fallback
      final response = await http.get(
        Uri.parse('$_baseUrl/rides/my_rides?user_id=$currentUserId'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API Service: Raw response data: $data');
        
        // The response is a direct list of rides
        if (data is List) {
          final rides = <Ride>[];
          for (final rideJson in data) {
            try {
              final ride = Ride.fromJson(Map<String, dynamic>.from(rideJson));
              rides.add(ride);
            } catch (e) {
              print('API Service: Error parsing ride: $e');
              print('API Service: Problematic ride data: $rideJson');
            }
          }
          print('Successfully loaded ${rides.length} rides from my_rides endpoint');
          return rides;
        } else {
          print('API Service: Unexpected response format - expected List, got ${data.runtimeType}');
          return [];
        }
      } else {
        print('Failed to get user rides: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting user rides: $e');
      return [];
    }
  }

  static Future<bool> updateDriverLocation(
    double latitude,
    double longitude,
    String? rideId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/location/update'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'ride_id': rideId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to update location: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating location: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRideParticipantsLocations(
    String rideId,
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/location/ride/$rideId/participants'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print('Failed to get ride participants locations: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting ride participants locations: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> requestRide(
    String rideId,
    String passengerId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rides/$rideId/request'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({
          'passenger_id': passengerId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to request ride: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': 'Failed to request ride: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error requesting ride: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> acceptPassengerRequest(
    String rideId,
    String passengerId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rides/$rideId/accept_passenger'),
        headers: _getAuthHeaders(token),
        body: jsonEncode({
          'passenger_id': passengerId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to accept passenger request: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'message': 'Failed to accept passenger request: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error accepting passenger request: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>?> getUserById(String userId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Failed to get user by ID: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
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
