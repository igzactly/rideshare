import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import 'package:provider/provider.dart';

class ScheduledRidesScreen extends StatefulWidget {
  const ScheduledRidesScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledRidesScreen> createState() => _ScheduledRidesScreenState();
}

class _ScheduledRidesScreenState extends State<ScheduledRidesScreen> {
  List<Map<String, dynamic>> scheduledRides = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScheduledRides();
  }

  Future<void> _loadScheduledRides() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      try {
        final rides = await ApiService.getScheduledRides(authProvider.token!);
        setState(() {
          scheduledRides = rides;
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load scheduled rides: $e')),
        );
      }
    }
  }

  void _showCreateScheduledRideDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateScheduledRideDialog(
        onRideCreated: _loadScheduledRides,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Rides'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : scheduledRides.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No scheduled rides yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create your first scheduled ride',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadScheduledRides,
                  child: ListView.builder(
                    itemCount: scheduledRides.length,
                    itemBuilder: (context, index) {
                      final ride = scheduledRides[index];
                      return ScheduledRideCard(
                        ride: ride,
                        onUpdated: _loadScheduledRides,
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateScheduledRideDialog,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class ScheduledRideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final VoidCallback onUpdated;

  const ScheduledRideCard({
    Key? key,
    required this.ride,
    required this.onUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheduledTime = DateTime.parse(ride['scheduled_time']);
    final isRecurring = ride['is_recurring'] ?? false;
    final status = ride['status'] ?? 'scheduled';

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ride['pickup']} → ${ride['dropoff']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_formatDateTime(scheduledTime)),
                if (isRecurring) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.repeat, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    ride['recurring_pattern'] ?? '',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${ride['max_passengers']} passengers'),
                const SizedBox(width: 16),
                const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('£${ride['price_per_seat']?.toStringAsFixed(2) ?? '0.00'} per seat'),
              ],
            ),
            if (ride['amenities'] != null && (ride['amenities'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (ride['amenities'] as List).map<Widget>((amenity) {
                  return Chip(
                    label: Text(amenity),
                    backgroundColor: Colors.blue.shade100,
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _activateRide(context),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Activate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _editRide(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _deleteRide(context),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'activated':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _activateRide(BuildContext context) {
    // Implement ride activation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride activation feature coming soon!')),
    );
  }

  void _editRide(BuildContext context) {
    // Implement ride editing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride editing feature coming soon!')),
    );
  }

  void _deleteRide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scheduled Ride'),
        content: const Text('Are you sure you want to delete this scheduled ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ride deletion feature coming soon!')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class CreateScheduledRideDialog extends StatefulWidget {
  final VoidCallback onRideCreated;

  const CreateScheduledRideDialog({
    Key? key,
    required this.onRideCreated,
  }) : super(key: key);

  @override
  State<CreateScheduledRideDialog> createState() => _CreateScheduledRideDialogState();
}

class _CreateScheduledRideDialogState extends State<CreateScheduledRideDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  DateTime? _scheduledTime;
  int _maxPassengers = 1;
  double _pricePerSeat = 0.0;
  String _rideType = 'standard';
  String _vehicleType = 'car';
  bool _isRecurring = false;
  String _recurringPattern = 'daily';
  List<String> _selectedAmenities = [];

  final List<String> _amenities = [
    'wifi',
    'charging_port',
    'air_conditioning',
    'music',
    'water',
    'snacks',
    'phone_charger',
    'car_seat',
    'wheelchair_accessible',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                'Create Scheduled Ride',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _pickupController,
                        decoration: const InputDecoration(
                          labelText: 'Pickup Location',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter pickup location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dropoffController,
                        decoration: const InputDecoration(
                          labelText: 'Dropoff Location',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter dropoff location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Scheduled Time'),
                        subtitle: Text(_scheduledTime != null
                            ? _formatDateTime(_scheduledTime!)
                            : 'Select time'),
                        trailing: const Icon(Icons.schedule),
                        onTap: () {
                          DatePicker.showDateTimePicker(
                            context,
                            showTitleActions: true,
                            onConfirm: (date) {
                              setState(() {
                                _scheduledTime = date;
                              });
                            },
                            currentTime: DateTime.now().add(const Duration(hours: 1)),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _maxPassengers,
                              decoration: const InputDecoration(
                                labelText: 'Max Passengers',
                                border: OutlineInputBorder(),
                              ),
                              items: List.generate(6, (index) => index + 1)
                                  .map((value) => DropdownMenuItem(
                                        value: value,
                                        child: Text('$value'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _maxPassengers = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Price per Seat (£)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _pricePerSeat = double.tryParse(value) ?? 0.0;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _rideType,
                              decoration: const InputDecoration(
                                labelText: 'Ride Type',
                                border: OutlineInputBorder(),
                              ),
                              items: ['standard', 'premium', 'eco', 'luxury']
                                  .map((value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value.toUpperCase()),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _rideType = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _vehicleType,
                              decoration: const InputDecoration(
                                labelText: 'Vehicle Type',
                                border: OutlineInputBorder(),
                              ),
                              items: ['car', 'van', 'motorcycle', 'electric_car']
                                  .map((value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value.toUpperCase()),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _vehicleType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Recurring Ride'),
                        value: _isRecurring,
                        onChanged: (value) {
                          setState(() {
                            _isRecurring = value!;
                          });
                        },
                      ),
                      if (_isRecurring) ...[
                        DropdownButtonFormField<String>(
                          value: _recurringPattern,
                          decoration: const InputDecoration(
                            labelText: 'Recurring Pattern',
                            border: OutlineInputBorder(),
                          ),
                          items: ['daily', 'weekly', 'monthly']
                              .map((value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.toUpperCase()),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _recurringPattern = value!;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Amenities',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _amenities.map((amenity) {
                          final isSelected = _selectedAmenities.contains(amenity);
                          return FilterChip(
                            label: Text(amenity),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedAmenities.add(amenity);
                                } else {
                                  _selectedAmenities.remove(amenity);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _createScheduledRide,
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _createScheduledRide() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a scheduled time')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    try {
      final rideData = {
        'pickup': _pickupController.text,
        'dropoff': _dropoffController.text,
        'pickup_coords': [51.5074, -0.1278], // Default London coordinates
        'dropoff_coords': [51.5074, -0.1278],
        'scheduled_time': _scheduledTime!.toIso8601String(),
        'max_passengers': _maxPassengers,
        'price_per_seat': _pricePerSeat,
        'ride_type': _rideType,
        'vehicle_type': _vehicleType,
        'amenities': _selectedAmenities,
        'is_recurring': _isRecurring,
        'recurring_pattern': _isRecurring ? _recurringPattern : null,
      };

      final result = await ApiService.createScheduledRide(rideData, authProvider.token!);
      
      if (result['success'] != false) {
        Navigator.pop(context);
        widget.onRideCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled ride created successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to create scheduled ride')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating scheduled ride: $e')),
      );
    }
  }
}
