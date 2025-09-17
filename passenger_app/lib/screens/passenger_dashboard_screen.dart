import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/ride_provider.dart';
import '../utils/theme.dart';
import '../models/ride.dart';
import '../services/api_service.dart';
import '../widgets/driver_info_widget.dart';
import 'find_rides_screen.dart';
import 'active_ride_screen.dart';

class PassengerDashboardScreen extends StatefulWidget {
  const PassengerDashboardScreen({super.key});

  @override
  State<PassengerDashboardScreen> createState() => _PassengerDashboardScreenState();
}

class _PassengerDashboardScreenState extends State<PassengerDashboardScreen> {
  List<Ride> _nearbyRides = [];
  bool _isLoadingNearby = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();
    final locationProvider = context.read<LocationProvider>();

    if (authProvider.token != null) {
      await Future.wait([
        rideProvider.loadUserRides(authProvider.token!),
        locationProvider.getCurrentLocation(),
      ]);
      
      // Load nearby rides
      await _loadNearbyRides();
    }
  }

  Future<void> _loadNearbyRides() async {
    final authProvider = context.read<AuthProvider>();
    final locationProvider = context.read<LocationProvider>();
    
    if (authProvider.token == null || locationProvider.currentLocation == null) {
      return;
    }

    setState(() {
      _isLoadingNearby = true;
    });

    try {
      final searchParams = {
        'pickup_location': {
          'latitude': locationProvider.currentLocation!.latitude,
          'longitude': locationProvider.currentLocation!.longitude,
        },
        'radius_km': 15.0,
      };
      
      final nearbyRides = await ApiService.searchRides(searchParams, authProvider.token!);
      
      setState(() {
        _nearbyRides = nearbyRides;
        _isLoadingNearby = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingNearby = false;
      });
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
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return IconButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/profile');
                },
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryBlue,
                  child: Text(
                    authProvider.currentUser?.name.isNotEmpty == true
                        ? authProvider.currentUser!.name[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 20),
              _buildSearchCard(),
              const SizedBox(height: 20),
              _buildMyBookings(),
              const SizedBox(height: 20),
              _buildNearbyRides(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryBlue, AppTheme.primaryPink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi ${authProvider.currentUser?.name ?? 'there'}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Where would you like to go today?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search,
            color: AppTheme.primaryBlue,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Find a Ride',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search for available rides near your location',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FindRidesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.search),
              label: const Text('Find Rides'),
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
    );
  }

  Widget _buildMyBookings() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        final myRides = rideProvider.userRides
            .where((ride) => ride.status != RideStatus.completed && ride.status != RideStatus.cancelled)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Bookings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/my-rides');
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (myRides.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkDivider),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.event_seat_outlined,
                      color: AppTheme.textSecondary,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No active bookings',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Book a ride to see it here',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...myRides.take(2).map((ride) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildRideCard(ride),
                  )),
          ],
        );
      },
    );
  }

  Widget _buildNearbyRides() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nearby Rides',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            IconButton(
              onPressed: _loadNearbyRides,
              icon: _isLoadingNearby
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingNearby)
          const Center(child: CircularProgressIndicator())
        else if (_nearbyRides.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkDivider),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.location_off_outlined,
                  color: AppTheme.textSecondary,
                  size: 48,
                ),
                SizedBox(height: 12),
                Text(
                  'No nearby rides',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Try searching in a different area',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _nearbyRides.length,
              itemBuilder: (context, index) {
                final ride = _nearbyRides[index];
                return Container(
                  width: 280,
                  margin: EdgeInsets.only(right: index == _nearbyRides.length - 1 ? 0 : 12),
                  child: _buildNearbyRideCard(ride),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRideCard(Ride ride) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ActiveRideScreen(ride: ride),
          ),
        );
      },
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
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyRideCard(Ride ride) {
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.flag, color: AppTheme.primaryPink, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.dropoffAddress,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Driver info
            if (ride.driverId != null && ride.driverId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DriverInfoWidget(
                  driverId: ride.driverId,
                  showCompact: true,
                ),
              ),
            Row(
              children: [
                const Icon(Icons.schedule, color: AppTheme.textSecondary, size: 14),
                const SizedBox(width: 4),
                Text(
                  ride.pickupTime.toString().substring(11, 16),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tap to book',
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
        // Refresh data
        await _loadData();
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

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.active:
        return AppTheme.primaryBlue;
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
        return 'Available';
      case RideStatus.pending:
        return 'Awaiting Approval';
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
}
