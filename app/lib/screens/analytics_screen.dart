import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? dashboardData;
  Map<String, dynamic>? environmentalData;
  bool isLoading = true;
  String selectedPeriod = 'month';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      try {
        final dashboard = await ApiService.getAnalyticsDashboard(
          authProvider.token!,
          period: selectedPeriod,
        );
        final environmental = await ApiService.getEnvironmentalAnalytics(
          authProvider.token!,
          period: selectedPeriod,
        );

        setState(() {
          dashboardData = dashboard;
          environmentalData = environmental;
          isLoading = false;
        });
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.eco), text: 'Environmental'),
            Tab(icon: Icon(Icons.trending_up), text: 'Trends'),
          ],
        ),
        actions: [
          DropdownButton<String>(
            value: selectedPeriod,
            items: const [
              DropdownMenuItem(value: 'week', child: Text('Week')),
              DropdownMenuItem(value: 'month', child: Text('Month')),
              DropdownMenuItem(value: 'year', child: Text('Year')),
            ],
            onChanged: (value) {
              setState(() {
                selectedPeriod = value!;
              });
              _loadAnalytics();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildEnvironmentalTab(),
                _buildTrendsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (dashboardData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildRideChart(),
          const SizedBox(height: 24),
          _buildFavoriteRoutes(),
          const SizedBox(height: 24),
          _buildPeakTimes(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Rides',
          '${dashboardData?['total_rides'] ?? 0}',
          Icons.directions_car,
          Colors.blue,
        ),
        _buildStatCard(
          'Completed Rides',
          '${dashboardData?['completed_rides'] ?? 0}',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Total Distance',
          '${(dashboardData?['total_distance_km'] ?? 0).toStringAsFixed(1)} km',
          Icons.straighten,
          Colors.orange,
        ),
        _buildStatCard(
          'Money Saved',
          '£${(dashboardData?['total_money_saved'] ?? 0).toStringAsFixed(2)}',
          Icons.savings,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideChart() {
    final rides = dashboardData?['total_rides'] ?? 0;
    final completed = dashboardData?['completed_rides'] ?? 0;
    final cancelled = rides - completed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ride Completion Rate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: completed.toDouble(),
                      title: 'Completed\n$completed',
                      color: Colors.green,
                      radius: 80,
                    ),
                    PieChartSectionData(
                      value: cancelled.toDouble(),
                      title: 'Cancelled\n$cancelled',
                      color: Colors.red,
                      radius: 80,
                    ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteRoutes() {
    final routes = dashboardData?['favorite_routes'] as List? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Favorite Routes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (routes.isEmpty)
              const Text('No favorite routes yet')
            else
              ...routes.map((route) => ListTile(
                    leading: const Icon(Icons.route),
                    title: Text(route['route'] ?? ''),
                    trailing: Text('${route['count']} rides'),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakTimes() {
    final peakTimes = dashboardData?['peak_usage_times'] as List? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Peak Usage Times',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (peakTimes.isEmpty)
              const Text('No peak time data yet')
            else
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: peakTimes.isNotEmpty 
                        ? (peakTimes.first['count'] as num).toDouble() * 1.2 
                        : 10,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toInt()}:00');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toInt().toString());
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: peakTimes.map((time) {
                      return BarChartGroupData(
                        x: time['hour'],
                        barRods: [
                          BarChartRodData(
                            toY: (time['count'] as num).toDouble(),
                            color: Colors.blue,
                            width: 16,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentalTab() {
    if (environmentalData == null) {
      return const Center(child: Text('No environmental data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEnvironmentalStats(),
          const SizedBox(height: 24),
          _buildCO2Chart(),
          const SizedBox(height: 24),
          _buildEnvironmentalImpact(),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'CO2 Saved',
          '${(environmentalData?['total_co2_saved_kg'] ?? 0).toStringAsFixed(1)} kg',
          Icons.eco,
          Colors.green,
        ),
        _buildStatCard(
          'Fuel Saved',
          '${(environmentalData?['total_fuel_saved_liters'] ?? 0).toStringAsFixed(1)} L',
          Icons.local_gas_station,
          Colors.orange,
        ),
        _buildStatCard(
          'Trees Equivalent',
          '${(environmentalData?['trees_equivalent'] ?? 0).toStringAsFixed(1)}',
          Icons.park,
          Colors.brown,
        ),
        _buildStatCard(
          'Environmental Score',
          '${environmentalData?['environmental_score'] ?? 0}/100',
          Icons.star,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildCO2Chart() {
    final dailyBreakdown = environmentalData?['daily_breakdown'] as Map? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily CO2 Savings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (dailyBreakdown.isEmpty)
              const Text('No daily data available')
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final entries = dailyBreakdown.entries.toList();
                            if (value.toInt() < entries.length) {
                              final date = entries[value.toInt()].key;
                              return Text(date.split('-').last); // Show only day
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toInt().toString());
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: dailyBreakdown.entries.map((entry) {
                          final index = dailyBreakdown.keys.toList().indexOf(entry.key);
                          return FlSpot(index.toDouble(), entry.value['co2_saved']?.toDouble() ?? 0);
                        }).toList(),
                        isCurved: true,
                        color: Colors.green,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentalImpact() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Environmental Impact',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildImpactItem(
              'CO2 Emissions Prevented',
              '${(environmentalData?['total_co2_saved_kg'] ?? 0).toStringAsFixed(1)} kg',
              'Equivalent to planting ${(environmentalData?['trees_equivalent'] ?? 0).toStringAsFixed(1)} trees',
              Icons.eco,
              Colors.green,
            ),
            const SizedBox(height: 16),
            _buildImpactItem(
              'Fuel Consumption Reduced',
              '${(environmentalData?['total_fuel_saved_liters'] ?? 0).toStringAsFixed(1)} liters',
              'Saving money and reducing emissions',
              Icons.local_gas_station,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildImpactItem(
              'Environmental Score',
              '${environmentalData?['environmental_score'] ?? 0}/100',
              'Your contribution to a greener planet',
              Icons.star,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactItem(String title, String value, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Trends Analysis',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Coming soon!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
