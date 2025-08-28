import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationPicker extends StatefulWidget {
  final String title;
  final String? initialAddress;
  final LatLng? initialLocation;
  final Function(LatLng location, String address) onLocationSelected;

  const LocationPicker({
    super.key,
    required this.title,
    this.initialAddress,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  List<Placemark> _searchResults = [];
  List<Location> _searchCoordinates = [];
  bool _isSearching = false;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialAddress ?? '';
    _selectedLocation = widget.initialLocation;
    _selectedAddress = widget.initialAddress ?? '';
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Center map on current location if no initial location
      if (_selectedLocation == null) {
        _mapController.move(_currentLocation!, 15.0);
      }
    } catch (e) {
      // Handle location permission errors
      debugPrint('Error getting current location: $e');
    }
  }

  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        setState(() {
          _searchResults = placemarks;
          _searchCoordinates = locations; // Store coordinates for later use
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _searchCoordinates = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _searchCoordinates = [];
        _isSearching = false;
      });
      debugPrint('Error searching locations: $e');
    }
  }

  void _selectLocation(LatLng location, String address) {
    setState(() {
      _selectedLocation = location;
      _selectedAddress = address;
      _searchController.text = address;
      _searchResults = [];
    });
    
    // Center map on selected location
    _mapController.move(location, 16.0);
  }

  void _onMapTap(TapPosition tapPosition, LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        
        _selectLocation(location, address);
      }
    } catch (e) {
      debugPrint('Error getting address for location: $e');
    }
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      widget.onLocationSelected(_selectedLocation!, _selectedAddress);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _confirmSelection,
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for a location...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      _searchLocations(value);
                    } else {
                      setState(() {
                        _searchResults = [];
                      });
                    }
                  },
                ),
                
                // Search Results
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final placemark = _searchResults[index];
                        final address = [
                          placemark.street,
                          placemark.subLocality,
                          placemark.locality,
                          placemark.administrativeArea,
                        ].where((e) => e != null && e.isNotEmpty).join(', ');
                        
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.blue),
                          title: Text(
                            placemark.name?.isNotEmpty == true 
                                ? placemark.name! 
                                : placemark.street ?? 'Unknown Street',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(address),
                                                       onTap: () {
                               // Use the stored coordinates for this search result
                               final index = _searchResults.indexOf(placemark);
                               if (index >= 0 && index < _searchCoordinates.length) {
                                 final location = LatLng(
                                   _searchCoordinates[index].latitude,
                                   _searchCoordinates[index].longitude,
                                 );
                                 _selectLocation(location, address);
                               }
                             },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation ?? 
                              _currentLocation ?? 
                              const LatLng(51.5074, -0.1278), // London default
                initialZoom: 15.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.rideshare_app',
                ),
                
                // Current Location Marker
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                
                // Selected Location Marker
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Bottom Info Panel
          if (_selectedLocation != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedAddress,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
