import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/ride_provider.dart';
import '../utils/theme.dart';
import '../widgets/location_picker.dart';
import 'package:latlong2/latlong.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _departureTimeController = TextEditingController();
  final _priceController = TextEditingController();
  
  DateTime? _selectedDepartureTime;
  bool _isCreatingRide = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _departureTimeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDepartureTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPurple,
              onPrimary: Colors.white,
              surface: AppTheme.darkCard,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppTheme.primaryPurple,
                onPrimary: Colors.white,
                surface: AppTheme.darkCard,
                onSurface: AppTheme.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDepartureTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          _departureTimeController.text =
              '${_selectedDepartureTime?.day}/${_selectedDepartureTime?.month}/${_selectedDepartureTime?.year} at ${time.format(context)}';
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

    final authProvider = context.read<AuthProvider>();
    final locationProvider = context.read<LocationProvider>();
    final rideProvider = context.read<RideProvider>();

    if (authProvider.token == null || authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
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
      'driver_id': authProvider.currentUser!.id,
      'price': double.parse(_priceController.text),
      'status': 'active',
    };

    print('Creating ride with data: $rideData');
    final success = await rideProvider.createRide(rideData, authProvider.token!);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride created successfully! You can now manage passenger requests.'),
          backgroundColor: Colors.green,
        ),
      );
      _clearForm();
      
      // Navigate to My Rides page
      Navigator.pushReplacementNamed(context, '/my-rides');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create ride. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isCreatingRide = false;
      });
    }
  }

  void _clearForm() {
    _pickupController.clear();
    _dropoffController.clear();
    _departureTimeController.clear();
    _priceController.clear();
    _selectedDepartureTime = null;
    context.read<LocationProvider>().clearLocations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Create Ride'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Offer a Ride',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a ride offer and wait for passenger requests',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),

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
                    borderSide: const BorderSide(color: AppTheme.primaryPurple),
                  ),
                  prefixIcon: const Icon(Icons.location_on, color: AppTheme.primaryPurple),
                  suffixIcon: const Icon(Icons.edit, color: AppTheme.textSecondary),
                ),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select pickup location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dropoff Location
              TextFormField(
                controller: _dropoffController,
                readOnly: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Dropoff Location',
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
                    borderSide: const BorderSide(color: AppTheme.primaryPurple),
                  ),
                  prefixIcon: const Icon(Icons.flag, color: AppTheme.primaryPink),
                  suffixIcon: const Icon(Icons.edit, color: AppTheme.textSecondary),
                ),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select dropoff location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Departure Time
              TextFormField(
                controller: _departureTimeController,
                readOnly: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Departure Time',
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
                    borderSide: const BorderSide(color: AppTheme.primaryPurple),
                  ),
                  prefixIcon: const Icon(Icons.schedule, color: AppTheme.primaryOrange),
                  suffixIcon: const Icon(Icons.calendar_today, color: AppTheme.textSecondary),
                ),
                onTap: _selectDepartureTime,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select departure time';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Price
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Price (£)',
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
                    borderSide: const BorderSide(color: AppTheme.primaryPurple),
                  ),
                  prefixIcon: const Icon(Icons.payment, color: AppTheme.primaryPurple),
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
              const SizedBox(height: 32),

              // Create Ride Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreatingRide ? null : _createRide,
                  icon: _isCreatingRide
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add),
                  label: Text(_isCreatingRide ? 'Creating...' : 'Create Ride'),
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
              const SizedBox(height: 16),

              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How it works',
                            style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'After creating your ride, passengers can request to join. You\'ll receive notifications for each request and can accept or decline them.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
