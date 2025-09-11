import 'package:latlong2/latlong.dart';

enum RideStatus {
  pending,
  accepted,
  inProgress,
  completed,
  cancelled,
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
    // Handle both frontend and backend data structures
    final id = json['id'] ?? json['_id'] ?? '';
    final passengerId = json['passenger_id'] ?? '';
    final driverId = json['driver_id'];
    
    // Handle location data - backend uses GeoJSON Point format
    LatLng pickupLocation;
    LatLng dropoffLocation;
    
    if (json['pickup_location'] != null && json['pickup_location']['coordinates'] != null) {
      // Backend GeoJSON format: [longitude, latitude]
      final coords = json['pickup_location']['coordinates'] as List;
      pickupLocation = LatLng(coords[1] ?? 0.0, coords[0] ?? 0.0);
    } else if (json['pickupLocation'] != null) {
      // Frontend format
      pickupLocation = LatLng(
        json['pickupLocation']['latitude'] ?? 0.0,
        json['pickupLocation']['longitude'] ?? 0.0,
      );
    } else {
      pickupLocation = const LatLng(0.0, 0.0);
    }
    
    if (json['dropoff_location'] != null && json['dropoff_location']['coordinates'] != null) {
      // Backend GeoJSON format: [longitude, latitude]
      final coords = json['dropoff_location']['coordinates'] as List;
      dropoffLocation = LatLng(coords[1] ?? 0.0, coords[0] ?? 0.0);
    } else if (json['dropoffLocation'] != null) {
      // Frontend format
      dropoffLocation = LatLng(
        json['dropoffLocation']['latitude'] ?? 0.0,
        json['dropoffLocation']['longitude'] ?? 0.0,
      );
    } else {
      dropoffLocation = const LatLng(0.0, 0.0);
    }
    
    // Handle address data - backend might use different field names
    final pickupAddress = json['pickup_address'] ?? json['pickup'] ?? '';
    final dropoffAddress = json['dropoff_address'] ?? json['dropoff'] ?? '';
    
    // Handle time data
    final pickupTime = json['pickup_time'] != null 
        ? DateTime.parse(json['pickup_time'])
        : DateTime.now();
    final actualPickupTime = json['actual_pickup_time'] != null
        ? DateTime.parse(json['actual_pickup_time'])
        : null;
    final completionTime = json['completion_time'] != null
        ? DateTime.parse(json['completion_time'])
        : null;
    
    // Handle numeric data
    final distance = (json['distance'] ?? json['total_distance_km'] ?? 0.0).toDouble();
    final price = (json['price'] ?? 0.0).toDouble();
    
    // Handle status - backend uses different status values
    RideStatus status;
    try {
      status = RideStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => RideStatus.pending,
      );
    } catch (e) {
      // Map backend status values to frontend enum
      switch (json['status']) {
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
    
    // Handle type - determine based on user role
    final type = driverId != null ? RideType.driver : RideType.passenger;
    
    // Handle metadata
    final metadata = json['metadata'] ?? {};
    
    // Handle timestamps
    final createdAt = json['created_at'] != null 
        ? DateTime.parse(json['created_at'])
        : DateTime.now();
    final updatedAt = json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
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
