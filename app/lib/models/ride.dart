import 'package:latlong2/latlong.dart';

enum RideStatus {
  active,      // Driver created ride, available for passengers
  pending,     // Passenger requested ride, waiting for driver acceptance
  accepted,    // Driver accepted passenger request
  inProgress,  // Ride started
  completed,   // Ride finished
  cancelled,   // Ride cancelled
}

enum RideType {
  passenger,
  driver,
}

class Ride {
  final String id;
  final String passengerId;
  final String? driverId;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime pickupTime;
  final DateTime? actualPickupTime;
  final DateTime? completionTime;
  final double distance;
  final double price;
  final RideStatus status;
  final RideType type;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ride({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupTime,
    this.actualPickupTime,
    this.completionTime,
    required this.distance,
    required this.price,
    required this.status,
    required this.type,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    try {
      print('Ride.fromJson: Parsing ride data: $json');
      
      // Convert dynamic map to String dynamic map to avoid type errors
      final Map<String, dynamic> safeJson = Map<String, dynamic>.from(json);
      // Handle both frontend and backend data structures
      final id = safeJson['id'] ?? safeJson['_id'] ?? '';
      final passengerId = safeJson['passenger_id'] ?? '';
      final driverId = safeJson['driver_id'];
      
      print('Ride.fromJson: ID: $id, Passenger: $passengerId, Driver: $driverId');
    
    // Handle location data - backend uses GeoJSON Point format
    LatLng pickupLocation;
    LatLng dropoffLocation;
    
    if (safeJson['pickup_location'] != null) {
      try {
        final pickupLoc = Map<String, dynamic>.from(safeJson['pickup_location']);
        if (pickupLoc['coordinates'] != null) {
          // Backend GeoJSON format: [longitude, latitude]
          final coords = pickupLoc['coordinates'] as List;
          pickupLocation = LatLng(coords[1] ?? 0.0, coords[0] ?? 0.0);
        } else {
          pickupLocation = const LatLng(0.0, 0.0);
        }
      } catch (e) {
        print('Ride.fromJson: Error parsing pickup_location: $e');
        pickupLocation = const LatLng(0.0, 0.0);
      }
    } else if (safeJson['pickupLocation'] != null) {
      try {
        final pickupLoc = Map<String, dynamic>.from(safeJson['pickupLocation']);
        pickupLocation = LatLng(
          pickupLoc['latitude'] ?? 0.0,
          pickupLoc['longitude'] ?? 0.0,
        );
      } catch (e) {
        print('Ride.fromJson: Error parsing pickupLocation: $e');
        pickupLocation = const LatLng(0.0, 0.0);
      }
    } else {
      pickupLocation = const LatLng(0.0, 0.0);
    }
    
    if (safeJson['dropoff_location'] != null) {
      try {
        final dropoffLoc = Map<String, dynamic>.from(safeJson['dropoff_location']);
        if (dropoffLoc['coordinates'] != null) {
          // Backend GeoJSON format: [longitude, latitude]
          final coords = dropoffLoc['coordinates'] as List;
          dropoffLocation = LatLng(coords[1] ?? 0.0, coords[0] ?? 0.0);
        } else {
          dropoffLocation = const LatLng(0.0, 0.0);
        }
      } catch (e) {
        print('Ride.fromJson: Error parsing dropoff_location: $e');
        dropoffLocation = const LatLng(0.0, 0.0);
      }
    } else if (safeJson['dropoffLocation'] != null) {
      try {
        final dropoffLoc = Map<String, dynamic>.from(safeJson['dropoffLocation']);
        dropoffLocation = LatLng(
          dropoffLoc['latitude'] ?? 0.0,
          dropoffLoc['longitude'] ?? 0.0,
        );
      } catch (e) {
        print('Ride.fromJson: Error parsing dropoffLocation: $e');
        dropoffLocation = const LatLng(0.0, 0.0);
      }
    } else {
      dropoffLocation = const LatLng(0.0, 0.0);
    }
    
    // Handle address data - backend uses different field names
    final pickupAddress = safeJson['pickup_address'] ?? safeJson['pickup'] ?? safeJson['pickupAddress'] ?? '';
    final dropoffAddress = safeJson['dropoff_address'] ?? safeJson['dropoff'] ?? safeJson['dropoffAddress'] ?? '';
    
    // Handle time data
    final pickupTime = safeJson['pickup_time'] != null 
        ? DateTime.parse(safeJson['pickup_time'])
        : DateTime.now();
    final actualPickupTime = safeJson['actual_pickup_time'] != null
        ? DateTime.parse(safeJson['actual_pickup_time'])
        : null;
    final completionTime = safeJson['completion_time'] != null
        ? DateTime.parse(safeJson['completion_time'])
        : null;
    
    // Handle numeric data
    final distance = (safeJson['distance'] ?? safeJson['total_distance_km'] ?? 0.0).toDouble();
    final price = (safeJson['price'] ?? 0.0).toDouble();
    
    // Handle status - backend uses different status values
    RideStatus status;
    try {
      status = RideStatus.values.firstWhere(
        (e) => e.toString().split('.').last == safeJson['status'],
        orElse: () => RideStatus.pending,
      );
    } catch (e) {
      // Map backend status values to frontend enum
      switch (safeJson['status']) {
        case 'active':
          status = RideStatus.pending;
          break;
        case 'accepted':
        case 'confirmed':
          status = RideStatus.accepted;
          break;
        case 'in_progress':
        case 'picked_up':
          status = RideStatus.inProgress;
          break;
        case 'completed':
        case 'dropped_off':
          status = RideStatus.completed;
          break;
        case 'cancelled':
          status = RideStatus.cancelled;
          break;
        default:
          status = RideStatus.pending;
      }
    }
    
    // Handle type - all rides are driver rides
    final type = RideType.driver;
    
    // Handle metadata
    final metadata = safeJson['metadata'] != null 
        ? Map<String, dynamic>.from(safeJson['metadata'])
        : <String, dynamic>{};
    
    // Handle timestamps
    final createdAt = safeJson['created_at'] != null 
        ? DateTime.parse(safeJson['created_at'])
        : DateTime.now();
    final updatedAt = safeJson['updated_at'] != null
        ? DateTime.parse(safeJson['updated_at'])
        : DateTime.now();
    
    return Ride(
      id: id,
      passengerId: passengerId,
      driverId: driverId,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupTime: pickupTime,
      actualPickupTime: actualPickupTime,
      completionTime: completionTime,
      distance: distance,
      price: price,
      status: status,
      type: type,
      metadata: metadata,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    } catch (e) {
      print('Ride.fromJson: Error parsing ride: $e');
      print('Ride.fromJson: Problematic JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'passenger_id': passengerId,
      'driver_id': driverId,
      'pickup_location': {
        'type': 'Point',
        'coordinates': [pickupLocation.longitude, pickupLocation.latitude],
      },
      'dropoff_location': {
        'type': 'Point',
        'coordinates': [dropoffLocation.longitude, dropoffLocation.latitude],
      },
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'pickup_time': pickupTime.toIso8601String(),
      'actual_pickup_time': actualPickupTime?.toIso8601String(),
      'completion_time': completionTime?.toIso8601String(),
      'distance': distance,
      'price': price,
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Ride copyWith({
    String? id,
    String? passengerId,
    String? driverId,
    LatLng? pickupLocation,
    LatLng? dropoffLocation,
    String? pickupAddress,
    String? dropoffAddress,
    DateTime? pickupTime,
    DateTime? actualPickupTime,
    DateTime? completionTime,
    double? distance,
    double? price,
    RideStatus? status,
    RideType? type,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ride(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      pickupTime: pickupTime ?? this.pickupTime,
      actualPickupTime: actualPickupTime ?? this.actualPickupTime,
      completionTime: completionTime ?? this.completionTime,
      distance: distance ?? this.distance,
      price: price ?? this.price,
      status: status ?? this.status,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Ride(id: $id, status: $status, type: $type, pickup: $pickupAddress)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ride && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
