import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../utils/theme.dart';
import '../models/ride.dart';
import '../widgets/passenger_info_widget.dart';
import 'active_ride_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();

    if (authProvider.token != null) {
      await rideProvider.loadUserRides(authProvider.token!);
    }
  }

  List<Ride> _getFilteredRides() {
    final rideProvider = context.read<RideProvider>();
    List<Ride> filtered = rideProvider.userRides;

    if (_selectedStatus != 'all') {
      final status = RideStatus.values.firstWhere(
        (e) => e.name == _selectedStatus,
        orElse: () => RideStatus.pending,
      );
      filtered = filtered.where((ride) => ride.status == status).toList();
    }

    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<void> _acceptPassengerRequest(Ride ride) async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();

    if (authProvider.token != null && ride.passengerId.isNotEmpty) {
      try {
        final success = await rideProvider.acceptPassengerRequest(
          ride.id,
          ride.passengerId,
          authProvider.token!,
        );
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passenger request accepted!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(rideProvider.error ?? 'Failed to accept passenger request'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error accepting passenger request: ${e.toString()}'),
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('My Created Rides'),
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
          // Header with description
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            color: AppTheme.darkSurface,
            child: const Text(
              'Manage your created rides and passenger requests',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
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
                        'all',
                        'active',
                        'pending',
                        'accepted',
                        'inProgress',
                        'completed',
                        'cancelled',
                      ].map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(_getStatusDisplayText(status)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? 'all';
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
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredRides = _getFilteredRides();

                if (filteredRides.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.local_taxi,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedStatus == 'all' ? 'No rides created yet' : 'No ${_getStatusDisplayText(_selectedStatus).toLowerCase()} rides',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a ride to start earning',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 14,
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildRideCard(ride),
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

  Widget _buildRideCard(Ride ride) {
    return GestureDetector(
      onTap: () => _showRideDetails(ride),
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
                    color: _getStatusColor(ride.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(ride.status),
                    style: TextStyle(
                      color: _getStatusColor(ride.status),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.primaryPurple, size: 16),
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: AppTheme.textSecondary, size: 14),
                const SizedBox(width: 4),
                Text(
                  ride.pickupTime.toString().substring(0, 16),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (ride.status == RideStatus.pending && ride.passengerId.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Passenger waiting',
                      style: TextStyle(
                        color: AppTheme.warningColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // Passenger info for rides with passengers
            if (ride.passengerId.isNotEmpty) ...[
              const SizedBox(height: 12),
              PassengerInfoWidget(
                passengerId: ride.passengerId,
                showCompact: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRideDetails(Ride ride) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActiveRideScreen(ride: ride),
      ),
    );
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return AppTheme.primaryPurple;
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
      case RideStatus.active:
        return 'Active';
      case RideStatus.pending:
        return 'Passenger Request';
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

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'all':
        return 'All Rides';
      case 'active':
        return 'Active';
      case 'pending':
        return 'Passenger Requests';
      case 'accepted':
        return 'Accepted';
      case 'inProgress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
