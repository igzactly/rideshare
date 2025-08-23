import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ride_provider.dart';
import '../providers/location_provider.dart';
import '../models/ride.dart';
import '../utils/theme.dart';

class RideSearchScreen extends StatefulWidget {
  const RideSearchScreen({super.key});

  @override
  State<RideSearchScreen> createState() => _RideSearchScreenState();
}

class _RideSearchScreenState extends State<RideSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _pickupTimeController = TextEditingController();
  DateTime? _selectedPickupTime;
  RideType _selectedRideType = RideType.passenger;

  @override
  void initState() {
    super.initState();
    _pickupTimeController.text = 'Now';
    _selectedPickupTime = DateTime.now();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _pickupTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectPickupTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedPickupTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(_selectedPickupTime ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _selectedPickupTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          _pickupTimeController.text =
              '${picked.day}/${picked.month}/${picked.year} at ${time.format(context)}';
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.getCurrentLocation();

    if (locationProvider.currentLocation != null) {
      setState(() {
        _pickupController.text = 'Current Location';
      });
    }
  }

  Future<void> _searchRides() async {
    if (_formKey.currentState!.validate()) {
      final rideProvider = context.read<RideProvider>();
      final locationProvider = context.read<LocationProvider>();

      try {
        // Set pickup and dropoff locations
        if (_pickupController.text == 'Current Location') {
          locationProvider.setPickupLocation(
              locationProvider.currentLocation!, 'Current Location');
        }

        // Search for available rides
        final searchParams = {
          'pickup_location': {
            'latitude': (locationProvider.pickupLocation ??
                    locationProvider.currentLocation!)
                .latitude,
            'longitude': (locationProvider.pickupLocation ??
                    locationProvider.currentLocation!)
                .longitude,
          },
          'dropoff_location': {
            'latitude': locationProvider.dropoffLocation!.latitude,
            'longitude': locationProvider.dropoffLocation!.longitude,
          },
          'pickup_time': _selectedPickupTime!.toIso8601String(),
          'ride_type': _selectedRideType.name,
        };

        await rideProvider.searchRides(searchParams, 'token');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Searching for available rides...'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error searching rides: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _createRide() async {
    if (_formKey.currentState!.validate()) {
      final rideProvider = context.read<RideProvider>();
      final locationProvider = context.read<LocationProvider>();

      try {
        final rideData = {
          'pickup_location': {
            'latitude': (locationProvider.pickupLocation ??
                    locationProvider.currentLocation!)
                .latitude,
            'longitude': (locationProvider.pickupLocation ??
                    locationProvider.currentLocation!)
                .longitude,
          },
          'dropoff_location': {
            'latitude': locationProvider.dropoffLocation!.latitude,
            'longitude': locationProvider.dropoffLocation!.longitude,
          },
          'pickup_address': _pickupController.text,
          'dropoff_address': _dropoffController.text,
          'pickup_time': _selectedPickupTime!.toIso8601String(),
          'ride_type': _selectedRideType.name,
        };

        final success = await rideProvider.createRide(rideData, 'token');

        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ride created successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Clear form
          _pickupController.clear();
          _dropoffController.clear();
          _pickupTimeController.text = 'Now';
          _selectedPickupTime = DateTime.now();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating ride: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Ride'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current Location Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.my_location,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Current Location',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Consumer<LocationProvider>(
                            builder: (context, locationProvider, child) {
                              return Text(
                                locationProvider.currentLocation != null
                                    ? '${locationProvider.currentLocation!.latitude.toStringAsFixed(4)}, ${locationProvider.currentLocation!.longitude.toStringAsFixed(4)}'
                                    : 'Not available',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Update Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Pickup Location
              TextFormField(
                controller: _pickupController,
                decoration: InputDecoration(
                  labelText: 'Pickup Location',
                  hintText: 'Enter pickup address or use current location',
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _useCurrentLocation,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter pickup location';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Dropoff Location
              TextFormField(
                controller: _dropoffController,
                decoration: InputDecoration(
                  labelText: 'Dropoff Location',
                  hintText: 'Enter destination address',
                  prefixIcon: const Icon(Icons.location_searching),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter dropoff location';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Pickup Time
              TextFormField(
                controller: _pickupTimeController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Pickup Time',
                  prefixIcon: const Icon(Icons.access_time),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _selectPickupTime,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: _selectPickupTime,
              ),

              const SizedBox(height: 16),

              // Ride Type Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ride Type',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: RideType.values.map((type) {
                          return ChoiceChip(
                            label: Text(type.name.toUpperCase()),
                            selected: _selectedRideType == type,
                            onSelected: (selected) {
                              setState(() {
                                _selectedRideType = type;
                              });
                            },
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: _selectedRideType == type
                                  ? Colors.white
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _searchRides,
                      icon: const Icon(Icons.search),
                      label: const Text('Search Rides'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _createRide,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Ride'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Available Rides Section
              Consumer<RideProvider>(
                builder: (context, rideProvider, child) {
                  if (rideProvider.availableRides.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No rides available yet. Create a ride request or search for existing ones.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Rides (${rideProvider.availableRides.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ...rideProvider.availableRides.map((ride) => Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppTheme.primaryColor,
                                child: Icon(
                                  Icons.directions_car,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                  '${ride.pickupAddress} → ${ride.dropoffAddress}'),
                              subtitle: Text(
                                '${ride.pickupTime.toString().substring(0, 16)} • ${ride.type.name}',
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  // Accept ride logic
                                  rideProvider.acceptRide(ride.id, 'token');
                                },
                                child: const Text('Accept'),
                              ),
                            ),
                          )),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
