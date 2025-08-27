import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';

class DriverModeScreen extends StatefulWidget {
  const DriverModeScreen({super.key});

  @override
  State<DriverModeScreen> createState() => _DriverModeScreenState();
}

class _DriverModeScreenState extends State<DriverModeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _departureTimeController = TextEditingController();
  final _seatsController = TextEditingController();
  final _priceController = TextEditingController();

  DateTime? _selectedDepartureTime;
  bool _isOnline = false;
  bool _isCreatingRide = false;

  @override
  void dispose() {
    _destinationController.dispose();
    _departureTimeController.dispose();
    _seatsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDepartureTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );

    if (picked != null) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
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
              '${_selectedDepartureTime!.day}/${_selectedDepartureTime!.month}/${_selectedDepartureTime!.year} at ${timePicked.format(context)}';
        });
      }
    }
  }

  Future<void> _createRide() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select departure time')),
      );
      return;
    }

    setState(() {
      _isCreatingRide = true;
    });

    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      final currentLocation = locationProvider.currentLocation;

      if (currentLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
        return;
      }

      final rideData = {
        'origin': {
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
          'address': 'Current Location',
        },
        'destination': {
          'latitude': 0.0, // TODO: Implement geocoding
          'longitude': 0.0,
          'address': _destinationController.text,
        },
        'departureTime': _selectedDepartureTime!.toIso8601String(),
        'availableSeats': int.parse(_seatsController.text),
        'pricePerSeat': double.parse(_priceController.text),
        'type': 'driver_offered',
      };

      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to create a ride'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final success =
          await rideProvider.createRide(rideData, authProvider.token!);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
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
    _destinationController.clear();
    _departureTimeController.clear();
    _seatsController.clear();
    _priceController.clear();
    setState(() {
      _selectedDepartureTime = null;
    });
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

                      // Destination
                      TextFormField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText: 'Destination',
                          hintText: 'Where are you going?',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter destination';
                          }
                          return null;
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

                      // Available Seats
                      TextFormField(
                        controller: _seatsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Available Seats',
                          hintText: 'How many seats?',
                          prefixIcon: Icon(Icons.airline_seat_recline_normal),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter available seats';
                          }
                          final seats = int.tryParse(value);
                          if (seats == null || seats < 1 || seats > 6) {
                            return 'Please enter a valid number (1-6)';
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
                          onPressed: _isOnline && !_isCreatingRide
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
                      leading: const Icon(Icons.history),
                      title: const Text('View Ride History'),
                      subtitle: const Text('See all your previous rides'),
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
