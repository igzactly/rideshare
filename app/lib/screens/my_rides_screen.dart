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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh rides when screen becomes visible
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

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.pending:
        return AppTheme.warningColor;
      case RideStatus.accepted:
        return AppTheme.primaryBlue;
      case RideStatus.inProgress:
        return AppTheme.successColor;
      case RideStatus.completed:
        return AppTheme.successColor;
      case RideStatus.cancelled:
        return AppTheme.errorColor;
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
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  const Text(
                    'Ride Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const Divider(color: AppTheme.darkDivider),
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
                          backgroundColor: AppTheme.primaryPurple,
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
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('My Rides'),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
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
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface,
              border: Border(
                bottom: BorderSide(color: AppTheme.darkDivider, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkDivider),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      dropdownColor: AppTheme.darkCard,
                      style: const TextStyle(color: AppTheme.textPrimary),
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkDivider),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      dropdownColor: AppTheme.darkCard,
                      style: const TextStyle(color: AppTheme.textPrimary),
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
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryPurple,
                    ),
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
                        const Text(
                          'Error loading rides',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rideProvider.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
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
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No rides found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You haven\'t taken any rides yet.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppTheme.darkDivider, width: 1),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'RIDE DETAILS',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'STATUS',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'ROLE',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'DATE',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 40), // Space for action button
                          ],
                        ),
                      ),
                      // Table Rows
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredRides.length,
                          itemBuilder: (context, index) {
                            final ride = filteredRides[index];
                            return _buildRideRow(ride);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideRow(Ride ride) {
    final statusColor = _getStatusColor(ride.status);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.darkDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ride.pickupAddress} → ${ride.dropoffAddress}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${ride.price.toStringAsFixed(2)} • ${ride.distance.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getStatusText(ride.status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _getTypeText(ride.type),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              ride.pickupTime.toString().substring(0, 10),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: () => _showRideDetails(ride),
            icon: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
