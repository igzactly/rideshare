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
    return Ride(
      id: json['id'] ?? '',
      passengerId: json['passenger_id'] ?? '',
      driverId: json['driver_id'],
      pickupLocation: LatLng(
        json['pickup_location']['coordinates'][1] ?? 0.0,
        json['pickup_location']['coordinates'][0] ?? 0.0,
      ),
      dropoffLocation: LatLng(
        json['dropoff_location']['coordinates'][1] ?? 0.0,
        json['dropoff_location']['coordinates'][0] ?? 0.0,
      ),
      pickupAddress: json['pickup_address'] ?? '',
      dropoffAddress: json['dropoff_address'] ?? '',
      pickupTime: DateTime.parse(
          json['pickup_time'] ?? DateTime.now().toIso8601String()),
      actualPickupTime: json['actual_pickup_time'] != null
          ? DateTime.parse(json['actual_pickup_time'])
          : null,
      completionTime: json['completion_time'] != null
          ? DateTime.parse(json['completion_time'])
          : null,
      distance: (json['distance'] ?? 0.0).toDouble(),
      price: (json['price'] ?? 0.0).toDouble(),
      status: RideStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => RideStatus.pending,
      ),
      type: RideType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => RideType.passenger,
      ),
      metadata: json['metadata'],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
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
