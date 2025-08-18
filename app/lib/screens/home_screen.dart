import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/location_provider.dart';
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
    const RideSearchScreen(),
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
      body: IndexedStack(
        index: _currentIndex,
        children: currentScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        items: _isDriverMode ? _driverNavItems : _passengerNavItems,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleMode,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        icon: Icon(_isDriverMode ? Icons.person : Icons.directions_car),
        label: Text(_isDriverMode ? 'Passenger Mode' : 'Driver Mode'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  List<BottomNavigationBarItem> get _passengerNavItems => [
        const BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Find Ride',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'My Rides',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];

  List<BottomNavigationBarItem> get _driverNavItems => [
        const BottomNavigationBarItem(
          icon: Icon(Icons.directions_car),
          label: 'Drive',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'My Rides',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
}
