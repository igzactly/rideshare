import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../providers/auth_provider.dart';
import '../models/ride.dart';
import '../utils/theme.dart';
import 'active_ride_screen.dart';
import 'ride_details_screen.dart';
import 'ride_completion_screen.dart';
import 'payment_received_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  String _selectedStatus = 'all';
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRides();
    });
  }

  Future<void> _loadRides() async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();

    if (authProvider.token != null) {
      await rideProvider.loadUserRides(authProvider.token!);
    }
  }

  String _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.pending:
        return '#FF9800'; // Orange
      case RideStatus.accepted:
        return '#2196F3'; // Blue
      case RideStatus.inProgress:
        return '#4CAF50'; // Green
      case RideStatus.completed:
        return '#4CAF50'; // Green
      case RideStatus.cancelled:
        return '#F44336'; // Red
    }
  }

  String _getStatusText(RideStatus status) {
    switch (status) {
      case RideStatus.pending:
        return 'Pending';
      case RideStatus.accepted:
        return 'Accepted';
      case RideStatus.inProgress:
        return 'In Progress';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getTypeText(RideType type) {
    switch (type) {
      case RideType.passenger:
        return 'Passenger';
      case RideType.driver:
        return 'Driver';
    }
  }

  List<Ride> _getFilteredRides(List<Ride> rides) {
    List<Ride> filtered = rides;

    if (_selectedStatus != 'all') {
      final status = RideStatus.values.firstWhere(
        (e) => e.name == _selectedStatus,
        orElse: () => RideStatus.pending,
      );
      filtered = filtered.where((ride) => ride.status == status).toList();
    }

    if (_selectedType != 'all') {
      final type = RideType.values.firstWhere(
        (e) => e.name == _selectedType,
        orElse: () => RideType.passenger,
      );
      filtered = filtered.where((ride) => ride.type == type).toList();
    }

    return filtered;
  }

  Future<void> _updateRideStatus(Ride ride, RideStatus newStatus) async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();

    if (authProvider.token != null) {
      try {
        await rideProvider.updateRideStatus(
            ride.id, newStatus.name, authProvider.token!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Ride status updated to ${_getStatusText(newStatus)}'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update ride status: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _navigateToRideScreen(Ride ride) {
    // Navigate to appropriate screen based on ride status and type
    if (ride.status == RideStatus.completed) {
      if (ride.type == RideType.passenger) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RideCompletionScreen(ride: ride),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PaymentReceivedScreen(ride: ride),
          ),
        );
      }
    } else if (ride.status == RideStatus.pending || 
               ride.status == RideStatus.accepted || 
               ride.status == RideStatus.inProgress) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ActiveRideScreen(ride: ride),
        ),
      );
    } else {
      // For cancelled rides, show details
      _showRideDetails(ride);
    }
  }

  void _showRideDetails(Ride ride) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ride Details',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow('Status', _getStatusText(ride.status)),
                    _buildDetailRow('Type', _getTypeText(ride.type)),
                    _buildDetailRow('Pickup', ride.pickupAddress),
                    _buildDetailRow('Dropoff', ride.dropoffAddress),
                    _buildDetailRow('Pickup Time',
                        ride.pickupTime.toString().substring(0, 16)),
                    if (ride.actualPickupTime != null)
                      _buildDetailRow('Actual Pickup',
                          ride.actualPickupTime!.toString().substring(0, 16)),
                    if (ride.completionTime != null)
                      _buildDetailRow('Completion',
                          ride.completionTime!.toString().substring(0, 16)),
                    _buildDetailRow(
                        'Distance', '${ride.distance.toStringAsFixed(1)} km'),
                    _buildDetailRow(
                        'Price', '\$${ride.price.toStringAsFixed(2)}'),
                    _buildDetailRow(
                        'Created', ride.createdAt.toString().substring(0, 16)),
                    const SizedBox(height: 20),

                    // Action Buttons
                    if (ride.status == RideStatus.pending)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _updateRideStatus(ride, RideStatus.accepted);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _updateRideStatus(ride, RideStatus.cancelled);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.errorColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),

                    if (ride.status == RideStatus.accepted)
                      ElevatedButton(
                        onPressed: () {
                          _updateRideStatus(ride, RideStatus.inProgress);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Ride'),
                      ),

                    if (ride.status == RideStatus.inProgress)
                      ElevatedButton(
                        onPressed: () {
                          _updateRideStatus(ride, RideStatus.completed);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Complete Ride'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rides'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadRides,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('All Statuses')),
                      ...RideStatus.values.map((status) => DropdownMenuItem(
                            value: status.name,
                            child: Text(_getStatusText(status)),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('All Types')),
                      ...RideType.values.map((type) => DropdownMenuItem(
                            value: type.name,
                            child: Text(_getTypeText(type)),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Rides List
          Expanded(
            child: Consumer<RideProvider>(
              builder: (context, rideProvider, child) {
                if (rideProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (rideProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading rides',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rideProvider.error!,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadRides,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredRides = _getFilteredRides(rideProvider.userRides);

                if (filteredRides.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No rides found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You haven\'t taken any rides yet.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRides.length,
                  itemBuilder: (context, index) {
                    final ride = filteredRides[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(int.parse(
                              _getStatusColor(ride.status)
                                  .replaceAll('#', '0xFF'))),
                          child: Icon(
                            ride.type == RideType.passenger
                                ? Icons.person
                                : Icons.directions_car,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          '${ride.pickupAddress} → ${ride.dropoffAddress}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getStatusText(ride.status)} • ${_getTypeText(ride.type)}',
                              style: TextStyle(
                                color: Color(int.parse(
                                    _getStatusColor(ride.status)
                                        .replaceAll('#', '0xFF'))),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${ride.pickupTime.toString().substring(0, 16)} • \$${ride.price.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          onPressed: () => _showRideDetails(ride),
                          icon: const Icon(Icons.info_outline),
                        ),
                        onTap: () => _navigateToRideScreen(ride),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
