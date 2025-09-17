import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/ride_provider.dart';
import '../utils/theme.dart';
import '../models/ride.dart';
import '../widgets/passenger_info_widget.dart';
import '../widgets/location_status_widget.dart';
import 'create_ride_screen.dart';
import 'active_ride_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
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
                  backgroundColor: AppTheme.primaryPurple,
                  child: Text(
                    authProvider.currentUser?.name.isNotEmpty == true
                        ? authProvider.currentUser!.name[0].toUpperCase()
                        : 'D',
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
              _buildQuickActions(),
              const SizedBox(height: 20),
              _buildActiveRides(),
              const SizedBox(height: 20),
              _buildPendingRequests(),
              const SizedBox(height: 20),
              _buildEarningsCard(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateRideScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Offer Ride'),
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
              colors: [AppTheme.primaryPurple, AppTheme.primaryPink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.3),
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
                    Icons.local_taxi,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${authProvider.currentUser?.name ?? 'Driver'}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ready to offer rides and earn money?',
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

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_road,
                title: 'Create Ride',
                subtitle: 'Offer a new ride',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CreateRideScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.list,
                title: 'My Rides',
                subtitle: 'View all rides',
                onTap: () {
                  Navigator.of(context).pushNamed('/my-rides');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkDivider),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryPurple,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRides() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        final activeRides = rideProvider.userRides
            .where((ride) => ride.status == RideStatus.inProgress)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Rides',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (activeRides.isEmpty)
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
                      Icons.directions_car_outlined,
                      color: AppTheme.textSecondary,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No active rides',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...activeRides.map((ride) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildRideCard(ride),
                  )),
          ],
        );
      },
    );
  }

  Widget _buildPendingRequests() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        final pendingRides = rideProvider.userRides
            .where((ride) => ride.status == RideStatus.pending)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Passenger Requests',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (pendingRides.isEmpty)
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
                      Icons.person_outline,
                      color: AppTheme.textSecondary,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No pending requests',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...pendingRides.map((ride) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildRideCard(ride),
                  )),
          ],
        );
      },
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
            // Passenger info
            if (ride.passengerId.isNotEmpty) ...[
              const SizedBox(height: 12),
              PassengerInfoWidget(
                passengerId: ride.passengerId,
                showCompact: true,
              ),
            ],
            // Live location status for in-progress rides
            if (ride.status == RideStatus.inProgress) ...[
              const SizedBox(height: 12),
              LocationStatusWidget(
                rideId: ride.id,
                token: context.read<AuthProvider>().token ?? '',
                isDriver: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Earnings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '£0.00',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryPurple,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '0 rides completed',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
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
}
