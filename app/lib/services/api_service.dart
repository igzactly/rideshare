import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/ride.dart';

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
      final response = await http.post(
        Uri.parse('$_baseUrl/rides/find'),
        headers: _getAuthHeaders(token),
        body: jsonEncode(searchParams),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rides = (data['rides'] as List)
            .map((rideJson) => Ride.fromJson(rideJson))
            .toList();
        return rides;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<List<Ride>> getUserRides(String token) async {
    try {
      // First, validate the token to get the user ID
      final validateResponse = await http.get(
        Uri.parse('$_baseUrl/auth/validate'),
        headers: _getAuthHeaders(token),
      );

      if (validateResponse.statusCode != 200) {
        print('Failed to validate token: ${validateResponse.statusCode}');
        return [];
      }

      final validateData = jsonDecode(validateResponse.body);
      final userId = validateData['user_id'];

      if (userId == null) {
        print('User ID not found in validation response');
        return [];
      }

      // Now get the user's rides
      final response = await http.get(
        Uri.parse('$_baseUrl/rides/user?user_id=$userId'),
        headers: _getAuthHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // The response is wrapped in a 'rides' object
        final rides = (data['rides'] as List)
            .map((rideJson) => Ride.fromJson(rideJson))
            .toList();
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

  // Health check
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
