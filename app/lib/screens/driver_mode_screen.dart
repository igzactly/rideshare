import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/location_picker.dart';
import '../screens/driver_rides_screen.dart';
import 'package:latlong2/latlong.dart';

class DriverModeScreen extends StatefulWidget {
  const DriverModeScreen({super.key});

  @override
  State<DriverModeScreen> createState() => _DriverModeScreenState();
}

class _DriverModeScreenState extends State<DriverModeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _departureTimeController = TextEditingController();
  final _priceController = TextEditingController();

  DateTime? _selectedDepartureTime;
  bool _isOnline = false;
  bool _isCreatingRide = false;

  @override
  void initState() {
    super.initState();
    // Load user rides when entering driver mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.token != null) {
        context.read<RideProvider>().loadUserRides(authProvider.token!);
      }
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _departureTimeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDepartureTime() async {
    final navigatorContext = context;
    final DateTime? picked = await showDatePicker(
      context: navigatorContext,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );

    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: navigatorContext,
        initialTime: TimeOfDay.now(),
      );

      if (timePicked != null) {
        setState(() {
          _selectedDepartureTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
          _departureTimeController.text =
              '${_selectedDepartureTime?.day}/${_selectedDepartureTime?.month}/${_selectedDepartureTime?.year} at ${timePicked.format(navigatorContext)}';
        });
      }
    }
  }

  Future<void> _createRide() async {
    if (_formKey.currentState?.validate() != true) {
      setState(() {
        _isCreatingRide = false;
      });
      return;
    }
    
    if (_selectedDepartureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select departure time')),
      );
      setState(() {
        _isCreatingRide = false;
      });
      return;
    }

    setState(() {
      _isCreatingRide = true;
    });

    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      
      // Check if pickup and dropoff locations are set
      if (locationProvider.pickupLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a pickup location'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isCreatingRide = false;
        });
        return;
      }
      
      if (locationProvider.dropoffLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a dropoff location'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isCreatingRide = false;
        });
        return;
      }

      final rideData = {
        'pickup_location': {
          'latitude': locationProvider.pickupLocation?.latitude ?? 0.0,
          'longitude': locationProvider.pickupLocation?.longitude ?? 0.0,
        },
        'dropoff_location': {
          'latitude': locationProvider.dropoffLocation?.latitude ?? 0.0,
          'longitude': locationProvider.dropoffLocation?.longitude ?? 0.0,
        },
        'pickup_address': _pickupController.text,
        'dropoff_address': _dropoffController.text,
        'pickup_time': _selectedDepartureTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'driver_id': null, // Will be set after authProvider is declared
        'price': double.parse(_priceController.text),
        'status': 'active', // Driver creates ride as 'active' - available for passengers
      };

      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Set the driver_id after authProvider is declared
      rideData['driver_id'] = authProvider.currentUser?.id;
      
      if (authProvider.token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to create a ride'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isCreatingRide = false;
        });
        return;
      }
      
      print('Creating ride with data: $rideData');
      final success =
          await rideProvider.createRide(rideData, authProvider.token!);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride created successfully! You can now manage passenger requests.'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
        
        // Navigate to My Created Rides page
        Navigator.pushReplacementNamed(context, '/my-rides');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create ride. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error creating ride: $e');
      if (mounted) {
        setState(() {
          _isCreatingRide = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingRide = false;
        });
      }
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _pickupController.clear();
    _dropoffController.clear();
    _departureTimeController.clear();
    _priceController.clear();
    setState(() {
      _selectedDepartureTime = null;
    });
    
    // Clear location provider locations
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    locationProvider.clearLocations();
  }

  void _toggleOnlineStatus() {
    setState(() {
      _isOnline = !_isOnline;
    });

    // TODO: Update driver status in backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnline ? 'You are now online' : 'You are now offline'),
        backgroundColor: _isOnline ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Mode'),
        actions: [
          Switch(
            value: _isOnline,
            onChanged: (value) => _toggleOnlineStatus(),
          ),
          const SizedBox(width: 8),
          Text(_isOnline ? 'Online' : 'Offline'),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isOnline ? Icons.check_circle : Icons.cancel,
                      size: 48,
                      color: _isOnline ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOnline ? 'Ready to Drive' : 'Currently Offline',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOnline
                          ? 'You can now offer rides to passengers'
                          : 'Go online to start offering rides',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Create Ride Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offer a Ride',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),

                      // Current Location Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final locationProvider = context.read<LocationProvider>();
                          await locationProvider.getCurrentLocation();
                          
                          if (locationProvider.currentLocation != null) {
                            setState(() {
                              _pickupController.text = 'Current Location';
                            });
                            locationProvider.setPickupLocation(
                              locationProvider.currentLocation!,
                              'Current Location',
                            );
                          }
                        },
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use Current Location as Pickup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          foregroundColor: Colors.blue[800],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Pickup Location
                      InkWell(
                        onTap: () async {
                          await Navigator.of(context).push(
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
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => LocationPicker(
                                title: 'Select Dropoff Location',
                                initialAddress: _dropoffController.text,
                                initialLocation: context.read<LocationProvider>().dropoffLocation != null
                                    ? LatLng(
                                        context.read<LocationProvider>().dropoffLocation?.latitude ?? 0.0,
                                        context.read<LocationProvider>().dropoffLocation?.longitude ?? 0.0,
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

                      // Location Status
                      Consumer<LocationProvider>(
                        builder: (context, locationProvider, child) {
                          return Row(
                            children: [
                              Icon(
                                locationProvider.pickupLocation != null 
                                    ? Icons.check_circle 
                                    : Icons.radio_button_unchecked,
                                color: locationProvider.pickupLocation != null 
                                    ? Colors.green 
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pickup: ${locationProvider.pickupLocation != null ? "Selected" : "Not set"}',
                                style: TextStyle(
                                  color: locationProvider.pickupLocation != null 
                                      ? Colors.green 
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Icon(
                                locationProvider.dropoffLocation != null 
                                    ? Icons.check_circle 
                                    : Icons.radio_button_unchecked,
                                color: locationProvider.dropoffLocation != null 
                                    ? Colors.green 
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Dropoff: ${locationProvider.dropoffLocation != null ? "Selected" : "Not set"}',
                                style: TextStyle(
                                  color: locationProvider.dropoffLocation != null 
                                      ? Colors.green 
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Departure Time
                      TextFormField(
                        controller: _departureTimeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Departure Time',
                          hintText: 'When are you leaving?',
                          prefixIcon: const Icon(Icons.schedule),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _selectDepartureTime,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select departure time';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Price per Seat
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price per Seat (£)',
                          hintText: 'How much per seat?',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter price';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price <= 0) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Create Ride Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isOnline && !_isCreatingRide && 
                                   _pickupController.text.isNotEmpty && 
                                   _dropoffController.text.isNotEmpty
                              ? _createRide
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                          child: _isCreatingRide
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Offer Ride',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.directions_car),
                      title: const Text('View My Rides'),
                      subtitle: const Text('See, edit, or delete your offered rides'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const DriverRidesScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Ride History'),
                      subtitle: const Text('See all your completed rides'),
                      onTap: () {
                        // Navigate to ride history
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.analytics),
                      title: const Text('Earnings'),
                      subtitle: const Text('Track your income'),
                      onTap: () {
                        // Navigate to earnings
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Driver Settings'),
                      subtitle: const Text('Vehicle info, preferences'),
                      onTap: () {
                        // Navigate to driver settings
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
