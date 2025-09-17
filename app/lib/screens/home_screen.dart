import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';

import '../providers/location_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../models/ride.dart';
import '../utils/theme.dart';
import '../widgets/driver_info_widget.dart';
import 'ride_search_screen.dart';
import 'my_rides_screen.dart';
import 'driver_mode_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isDriverMode = false;

  final List<Widget> _passengerScreens = [
    const DashboardScreen(),
    const MyRidesScreen(),
    const ProfileScreen(),
  ];

  final List<Widget> _driverScreens = [
    const DriverModeScreen(),
    const MyRidesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.initializeLocation();
  }

  void _toggleMode() {
    setState(() {
      _isDriverMode = !_isDriverMode;
      _currentIndex = 0; // Reset to first tab when switching modes
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentScreens = _isDriverMode ? _driverScreens : _passengerScreens;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: currentScreens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.darkSurface,
          border: Border(
            top: BorderSide(color: AppTheme.darkDivider, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.primaryPurple,
          unselectedItemColor: AppTheme.textSecondary,
          items: _isDriverMode ? _driverNavItems : _passengerNavItems,
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.purpleGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _toggleMode,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: Icon(_isDriverMode ? Icons.person : Icons.directions_car),
          label: Text(_isDriverMode ? 'Passenger Mode' : 'Driver Mode'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  List<BottomNavigationBarItem> get _passengerNavItems => [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'My Rides',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];

  List<BottomNavigationBarItem> get _driverNavItems => [
        const BottomNavigationBarItem(
          icon: Icon(Icons.directions_car_outlined),
          activeIcon: Icon(Icons.directions_car),
          label: 'Drive',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'My Rides',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to defer the call until after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();
    final locationProvider = context.read<LocationProvider>();
    
    if (authProvider.token != null) {
      // Load user's rides
      await rideProvider.loadUserRides(authProvider.token!);
      
      // Load nearby rides based on current location
      await _loadNearbyRides();
    }
  }

  Future<void> _loadNearbyRides() async {
    final authProvider = context.read<AuthProvider>();
    final rideProvider = context.read<RideProvider>();
    final locationProvider = context.read<LocationProvider>();
    
    if (authProvider.token == null) return;
    
    // Use current location if available, otherwise use a default location
    LatLng searchLocation;
    if (locationProvider.currentLocation != null) {
      searchLocation = locationProvider.currentLocation!;
    } else {
      // Use London as default location
      searchLocation = const LatLng(51.5074, -0.1278);
    }
    
    // Search for nearby rides
    final searchParams = {
      'pickup_location': {
        'latitude': searchLocation.latitude,
        'longitude': searchLocation.longitude,
      },
      'radius_km': 10.0, // Search within 10km
    };
    
    try {
      await rideProvider.searchRides(searchParams, authProvider.token!);
    } catch (e) {
      print('Error loading nearby rides: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header with search and profile
            _buildHeader(),
            
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Actions
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    
                    // Current Openings (Available Rides)
                    _buildCurrentOpenings(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.darkDivider, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.purpleGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_taxi,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'RideShare',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          
          // Notifications
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppTheme.successColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // Profile
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppTheme.blueGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find Your Ride',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        // Google-style search bar
        Container(
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.darkDivider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RideSearchScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Where do you want to go?',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: AppTheme.primaryPurple,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildCurrentOpenings() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nearby Available Rides${rideProvider.availableRides.isNotEmpty ? ' (${rideProvider.availableRides.length})' : ''}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkDivider),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sort By: Distance',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: rideProvider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPurple,
                      ),
                    )
                  : rideProvider.availableRides.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_taxi_outlined,
                                size: 48,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No nearby rides available',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: rideProvider.availableRides.length,
                          itemBuilder: (context, index) {
                            return _buildNearbyRideCard(rideProvider.availableRides[index], index);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNearbyRideCard(Ride ride, int index) {
    final gradients = [
      AppTheme.blueGradient,
      AppTheme.redGradient,
      AppTheme.orangeGradient,
      AppTheme.greenGradient,
    ];
    
    // Use actual ride data
    final pickupLocation = ride.pickupAddress.isNotEmpty ? ride.pickupAddress : 'Unknown Location';
    final dropoffLocation = ride.dropoffAddress.isNotEmpty ? ride.dropoffAddress : 'Unknown Destination';
    final price = ride.price;
    final status = ride.status.toString().split('.').last;
    
    // Calculate distance (simplified - in a real app you'd calculate actual distance)
    final distance = '${(index + 1) * 0.5} km away';
    
    return GestureDetector(
      onTap: () {
        _showRideRequestDialog(ride);
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          gradient: gradients[index % gradients.length],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                pickupLocation,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '→ $dropoffLocation',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              DriverInfoWidget(
                driverId: ride.driverId,
                isCompact: true,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '£${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        distance,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRideRequestDialog(Ride ride) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Request Ride'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From: ${ride.pickupAddress}'),
              const SizedBox(height: 8),
              Text('To: ${ride.dropoffAddress}'),
              const SizedBox(height: 8),
              Text('Price: £${ride.price.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('Pickup Time: ${ride.pickupTime.toString().substring(0, 16)}'),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to request this ride?',
                style: TextStyle(fontWeight: FontWeight.w500),
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
                backgroundColor: AppTheme.primaryPurple,
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
