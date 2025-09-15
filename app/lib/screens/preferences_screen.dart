import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({Key? key}) : super(key: key);

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  Map<String, dynamic>? preferences;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      try {
        final prefs = await ApiService.getUserPreferences(authProvider.token!);
        setState(() {
          preferences = prefs;
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load preferences: $e')),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    if (preferences == null) return;

    setState(() {
      isSaving = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      try {
        final result = await ApiService.updateUserPreferences(preferences!, authProvider.token!);
        
        if (result['success'] != false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preferences saved successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to save preferences')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    }

    setState(() {
      isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Preferences'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _savePreferences,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : preferences == null
              ? const Center(child: Text('Failed to load preferences'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRideTypePreferences(),
                      const SizedBox(height: 24),
                      _buildVehiclePreferences(),
                      const SizedBox(height: 24),
                      _buildAmenityPreferences(),
                      const SizedBox(height: 24),
                      _buildPricingPreferences(),
                      const SizedBox(height: 24),
                      _buildRoutePreferences(),
                      const SizedBox(height: 24),
                      _buildComfortPreferences(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRideTypePreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preferred Ride Types',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['standard', 'premium', 'eco', 'luxury'].map((type) {
                final isSelected = (preferences!['preferred_ride_types'] as List?)?.contains(type) ?? false;
                return FilterChip(
                  label: Text(type.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      final types = List<String>.from(preferences!['preferred_ride_types'] ?? []);
                      if (selected) {
                        if (!types.contains(type)) types.add(type);
                      } else {
                        types.remove(type);
                      }
                      preferences!['preferred_ride_types'] = types;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclePreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preferred Vehicle Types',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['car', 'van', 'motorcycle', 'electric_car', 'hybrid_car'].map((type) {
                final isSelected = (preferences!['preferred_vehicle_types'] as List?)?.contains(type) ?? false;
                return FilterChip(
                  label: Text(type.replaceAll('_', ' ').toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      final types = List<String>.from(preferences!['preferred_vehicle_types'] ?? []);
                      if (selected) {
                        if (!types.contains(type)) types.add(type);
                      } else {
                        types.remove(type);
                      }
                      preferences!['preferred_vehicle_types'] = types;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenityPreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Required Amenities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                'wifi',
                'charging_port',
                'air_conditioning',
                'music',
                'water',
                'snacks',
                'phone_charger',
                'car_seat',
                'wheelchair_accessible',
              ].map((amenity) {
                final isSelected = (preferences!['required_amenities'] as List?)?.contains(amenity) ?? false;
                return FilterChip(
                  label: Text(amenity.replaceAll('_', ' ').toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      final amenities = List<String>.from(preferences!['required_amenities'] ?? []);
                      if (selected) {
                        if (!amenities.contains(amenity)) amenities.add(amenity);
                      } else {
                        amenities.remove(amenity);
                      }
                      preferences!['required_amenities'] = amenities;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingPreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pricing Preferences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: preferences!['max_price_per_km']?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Maximum Price per KM (£)',
                border: OutlineInputBorder(),
                prefixText: '£',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                preferences!['max_price_per_km'] = double.tryParse(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutePreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Preferences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: preferences!['max_detour_minutes'] ?? 15,
                    decoration: const InputDecoration(
                      labelText: 'Max Detour Time',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: AppTheme.darkCard,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: [5, 10, 15, 20, 30].map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text('$value minutes', style: const TextStyle(color: AppTheme.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        preferences!['max_detour_minutes'] = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: preferences!['preferred_pickup_time_buffer'] ?? 5,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Buffer',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: AppTheme.darkCard,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: [0, 5, 10, 15, 30].map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text('$value min early', style: const TextStyle(color: AppTheme.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        preferences!['preferred_pickup_time_buffer'] = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Avoid Tolls'),
              value: preferences!['avoid_tolls'] ?? false,
              onChanged: (value) {
                setState(() {
                  preferences!['avoid_tolls'] = value;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Avoid Highways'),
              value: preferences!['avoid_highways'] ?? false,
              onChanged: (value) {
                setState(() {
                  preferences!['avoid_highways'] = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComfortPreferences() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comfort Preferences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: preferences!['preferred_music'] ?? 'none',
              decoration: const InputDecoration(
                labelText: 'Music Preference',
                border: OutlineInputBorder(),
              ),
              dropdownColor: AppTheme.darkCard,
              style: const TextStyle(color: AppTheme.textPrimary),
              items: [
                'none',
                'classical',
                'pop',
                'rock',
                'jazz',
                'electronic',
                'country',
                'hip_hop',
                'user_choice',
              ].map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(value.toUpperCase(), style: const TextStyle(color: AppTheme.textPrimary)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  preferences!['preferred_music'] = value;
                });
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Smoking Allowed'),
              value: preferences!['smoking_allowed'] ?? false,
              onChanged: (value) {
                setState(() {
                  preferences!['smoking_allowed'] = value;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Pets Allowed'),
              value: preferences!['pets_allowed'] ?? false,
              onChanged: (value) {
                setState(() {
                  preferences!['pets_allowed'] = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
