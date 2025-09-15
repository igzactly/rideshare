import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ride_provider.dart';
import '../providers/location_provider.dart';
import '../providers/auth_provider.dart';
import '../models/ride.dart';
import '../utils/theme.dart';
import '../widgets/location_picker.dart';
import 'package:latlong2/latlong.dart';
import 'active_ride_screen.dart';

class RideSearchScreen extends StatefulWidget {
  const RideSearchScreen({super.key});

  @override
  State<RideSearchScreen> createState() => _RideSearchScreenState();
}

class _RideSearchScreenState extends State<RideSearchScreen> {
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
    final rideProvider = context.read<RideProvider>();
    final locationProvider = context.read<LocationProvider>();
    final authProvider = context.read<AuthProvider>();

    try {
      // Check if user is authenticated
      if (authProvider.token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to search rides'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if current location is available
      if (locationProvider.currentLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services to search rides'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Set pickup location if using current location
      if (_pickupController.text == 'Current Location') {
        locationProvider.setPickupLocation(
            locationProvider.currentLocation!, 'Current Location');
      }

      // Check if dropoff location is set
      if (locationProvider.dropoffLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a dropoff location using the location picker'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
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
        'pickup_time': _selectedPickupTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'ride_type': _selectedRideType.name,
      };

      await rideProvider.searchRides(searchParams, authProvider.token!);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Ride'),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
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
                          color: AppTheme.primaryPurple,
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
                                    color: AppTheme.textSecondary,
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
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pickup Location
            InkWell(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LocationPicker(
                      title: 'Select Pickup Location',
                      initialAddress: _pickupController.text,
                      initialLocation: context.read<LocationProvider>().pickupLocation != null
                          ? LatLng(
                              context.read<LocationProvider>().pickupLocation!.latitude,
                              context.read<LocationProvider>().pickupLocation!.longitude,
                            )
                          : null,
                      onLocationSelected: (location, address) {
                        setState(() {
                          _pickupController.text = address;
                        });
                        context.read<LocationProvider>().setPickupLocation(
                          LatLng(location.latitude, location.longitude),
                          address,
                        );
                      },
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup Location',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _pickupController.text.isEmpty
                                ? 'Tap to select pickup location'
                                : _pickupController.text,
                            style: TextStyle(
                              fontSize: 16,
                              color: _pickupController.text.isEmpty
                                  ? Colors.grey[400]
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Dropoff Location
            InkWell(
              onTap: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LocationPicker(
                      title: 'Select Dropoff Location',
                      initialAddress: _dropoffController.text,
                      initialLocation: context.read<LocationProvider>().dropoffLocation != null
                          ? LatLng(
                              context.read<LocationProvider>().dropoffLocation!.latitude,
                              context.read<LocationProvider>().dropoffLocation!.longitude,
                            )
                          : null,
                      onLocationSelected: (location, address) {
                        setState(() {
                          _dropoffController.text = address;
                        });
                        context.read<LocationProvider>().setDropoffLocation(
                          LatLng(location.latitude, location.longitude),
                          address,
                        );
                      },
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_searching, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dropoff Location',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dropoffController.text.isEmpty
                                ? 'Tap to select destination'
                                : _dropoffController.text,
                            style: TextStyle(
                              fontSize: 16,
                              color: _dropoffController.text.isEmpty
                                  ? Colors.grey[400]
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
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
                          selectedColor: AppTheme.primaryPurple,
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
                      backgroundColor: AppTheme.primaryPink,
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
                    onPressed: () {
                      // Navigate to ride search or show available rides
                      // This button can be repurposed for other functionality
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Find Rides'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
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
                          backgroundColor: AppTheme.primaryPurple,
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
                          onPressed: () async {
                            // Accept ride logic
                            final authProvider = context.read<AuthProvider>();
                            if (authProvider.token != null && authProvider.currentUser != null) {
                              final success = await rideProvider.acceptRide(
                                ride.id, 
                                authProvider.token!, 
                                authProvider.currentUser!.id
                              );
                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ride accepted successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                
                                // Navigate to active ride screen
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => ActiveRideScreen(ride: ride),
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please login to accept rides'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
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
    );
  }
}
