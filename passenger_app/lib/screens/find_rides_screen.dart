import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/ride_provider.dart';
import '../utils/theme.dart';
import '../models/ride.dart';
import '../widgets/location_picker.dart';
import '../widgets/driver_info_widget.dart';
import '../services/api_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

class FindRidesScreen extends StatefulWidget {
  const FindRidesScreen({super.key});

  @override
  State<FindRidesScreen> createState() => _FindRidesScreenState();
}

class _FindRidesScreenState extends State<FindRidesScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _pickupTimeController = TextEditingController();
  DateTime? _selectedPickupTime;
  bool _isSearching = false;
  List<Ride> _searchResults = [];

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _pickupTimeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.getCurrentLocation();
    
    if (locationProvider.currentLocation != null) {
      try {
        // Get actual address for current location
        final placemarks = await placemarkFromCoordinates(
          locationProvider.currentLocation!.latitude,
          locationProvider.currentLocation!.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final address = [
            placemark.name,
            placemark.street,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
          
          _pickupController.text = address.isNotEmpty ? address : 'Current Location';
          
          // Set the pickup location in the provider
          locationProvider.setPickupLocation(
            locationProvider.currentLocation!,
            _pickupController.text,
          );
        } else {
          _pickupController.text = 'Current Location';
        }
      } catch (e) {
        print('Error getting address for current location: $e');
        _pickupController.text = 'Current Location';
      }
    }
  }

  Future<void> _searchRides() async {
    final authProvider = context.read<AuthProvider>();
    final locationProvider = context.read<LocationProvider>();
    
    if (authProvider.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to search rides'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (locationProvider.pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pickup location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final searchParams = {
        'pickup_location': {
          'latitude': locationProvider.pickupLocation!.latitude,
          'longitude': locationProvider.pickupLocation!.longitude,
        },
        'radius_km': 15.0,
      };
      
      final results = await ApiService.searchRides(searchParams, authProvider.token!);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Find Rides'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface,
              border: Border(
                bottom: BorderSide(color: AppTheme.darkDivider, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Pickup Location
                TextFormField(
                  controller: _pickupController,
                  readOnly: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Pickup Location',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.darkCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.darkDivider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.darkDivider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue),
                    ),
                    prefixIcon: const Icon(Icons.location_on, color: AppTheme.primaryBlue),
                    suffixIcon: const Icon(Icons.edit, color: AppTheme.textSecondary),
                  ),
                  onTap: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => LocationPicker(
                          title: 'Select Pickup Location',
                          initialAddress: _pickupController.text,
                          initialLocation: context.read<LocationProvider>().pickupLocation != null
                              ? LatLng(
                                  context.read<LocationProvider>().pickupLocation?.latitude ?? 0.0,
                                  context.read<LocationProvider>().pickupLocation?.longitude ?? 0.0,
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
                ),
                const SizedBox(height: 16),
                // Search Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching ? null : _searchRides,
                    icon: _isSearching 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isSearching ? 'Searching...' : 'Find Rides'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
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
          ),
          // Search Results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryBlue),
            SizedBox(height: 16),
            Text(
              'Searching for nearby rides...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No rides found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching in a different area or check back later',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final ride = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRideCard(ride),
        );
      },
    );
  }

  Widget _buildRideCard(Ride ride) {
    return GestureDetector(
      onTap: () => _showRideRequestDialog(ride),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Available',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '£${ride.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.primaryBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.pickupAddress,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, color: AppTheme.primaryPink, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.dropoffAddress,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Driver information
            DriverInfoWidget(
              driverId: ride.driverId,
              showCompact: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: AppTheme.textSecondary, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Pickup: ${ride.pickupTime.toString().substring(11, 16)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tap to request',
                    style: TextStyle(
                      color: AppTheme.primaryPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRideRequestDialog(Ride ride) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('Request Ride', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From: ${ride.pickupAddress}', style: const TextStyle(color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('To: ${ride.dropoffAddress}', style: const TextStyle(color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Price: £${ride.price.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Pickup Time: ${ride.pickupTime.toString().substring(0, 16)}', style: const TextStyle(color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              const Text('Driver:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              DriverInfoWidget(
                driverId: ride.driverId,
                showCompact: false,
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to request this ride?',
                style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _requestRide(ride);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Request Ride'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestRide(Ride ride) async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();
    
    if (authProvider.token == null || authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to request rides'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final success = await rideProvider.requestRide(
        ride.id,
        authProvider.currentUser?.id ?? '',
        authProvider.token ?? '',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request sent! Waiting for driver acceptance...'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to dashboard
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rideProvider.error ?? 'Failed to request ride'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
