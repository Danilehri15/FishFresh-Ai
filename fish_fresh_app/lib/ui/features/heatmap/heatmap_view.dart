import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/services/api_service.dart';
import '../../../data/models/heatmap_model.dart';
import '../../core/theme.dart';

class HeatmapView extends StatefulWidget {
  const HeatmapView({super.key});

  @override
  State<HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends State<HeatmapView> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  bool _isLoading = true;
  String _selectedCity = 'all';
  List<MarketHeatmapPoint> _heatmapData = [];

  int _totalScans = 0;
  int _recommendedCount = 0;
  int _avoidCount = 0;

  final List<String> _cities = [
    'all',
    'Karachi',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.fetchHeatmapData(city: _selectedCity);
      final recommended = await _apiService.fetchRecommendedMarkets(
        city: _selectedCity,
      );
      final avoid = await _apiService.fetchAvoidMarkets(city: _selectedCity);

      int total = 0;
      for (var point in data) {
        total += point.totalScans;
      }

      setState(() {
        _heatmapData = data;
        _totalScans = total;
        _recommendedCount = recommended.length;
        _avoidCount = avoid.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showMarketDetails(MarketHeatmapPoint market) {
    final freshPct = (market.avgFreshnessScore * 100);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                market.marketName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(
                      market.city,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: AppTheme.primaryTeal,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      market.qualityRating,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: market.color,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Circular freshness gauge + stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Circular gauge
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: market.avgFreshnessScore.clamp(0.0, 1.0),
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              market.color,
                            ),
                            backgroundColor: market.color.withAlpha(35),
                          ),
                        ),
                        Text(
                          '${freshPct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: market.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatIndicator(
                    'Total Scans',
                    '${market.totalScans}',
                    AppTheme.accentCyan,
                  ),
                  _buildStatIndicator(
                    'Fresh',
                    '${market.freshCount}',
                    AppTheme.freshGreen,
                  ),
                  _buildStatIndicator(
                    'Spoiled',
                    '${market.spoiledCount}',
                    AppTheme.spoiledRed,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Fresh vs Spoiled bar
              if (market.totalScans > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      if (market.freshCount > 0)
                        Expanded(
                          flex: market.freshCount,
                          child: Container(
                            height: 8,
                            color: AppTheme.freshGreen,
                          ),
                        ),
                      if (market.spoiledCount > 0)
                        Expanded(
                          flex: market.spoiledCount,
                          child: Container(
                            height: 8,
                            color: AppTheme.spoiledRed,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (market.recommendation.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: market.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: market.color.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        market.qualityRating == 'AVOID' ||
                                market.qualityRating == 'CAUTION'
                            ? Icons.warning_amber_rounded
                            : Icons.recommend,
                        color: market.color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          market.recommendation,
                          style: TextStyle(
                            fontSize: 14,
                            color: market.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Market Quality Map', style: TextStyle(color: Colors.white)),
            Text(
              'Crowd-sourced freshness heatmap',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          DropdownButton<String>(
            dropdownColor: AppTheme.primaryDark,
            value: _selectedCity,
            style: const TextStyle(color: Colors.white),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            underline: const SizedBox(),
            items: _cities.map((city) {
              return DropdownMenuItem<String>(
                value: city,
                child: Text(city == 'all' ? 'All Cities' : city),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedCity = val);
                _fetchData();
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            )
          : Column(
              children: [
                // Summary cards row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildSummaryCard(
                        'Total Markets',
                        '${_heatmapData.length}',
                        Icons.store,
                      ),
                      _buildSummaryCard(
                        'Recommended',
                        '$_recommendedCount',
                        Icons.thumb_up,
                        color: AppTheme.freshGreen,
                      ),
                      _buildSummaryCard(
                        'Avoid',
                        '$_avoidCount',
                        Icons.warning,
                        color: AppTheme.spoiledRed,
                      ),
                      _buildSummaryCard(
                        'Crowd Scans',
                        '$_totalScans',
                        Icons.group,
                      ),
                    ],
                  ),
                ),
                // Map with markers
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _getMapCenter(),
                          initialZoom: _getMapZoom(),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.fish_fresh_app',
                          ),
                          CircleLayer(
                            circles: _heatmapData.map((market) {
                              return CircleMarker(
                                point: LatLng(
                                  market.latitude,
                                  market.longitude,
                                ),
                                color: market.color.withAlpha(150),
                                borderColor: market.color,
                                borderStrokeWidth: 2,
                                useRadiusInMeter: false,
                                radius: (12 + (market.totalScans / 2)).clamp(
                                  12.0,
                                  35.0,
                                ),
                              );
                            }).toList(),
                          ),
                          MarkerLayer(
                            markers: _heatmapData.map((market) {
                              return Marker(
                                point: LatLng(
                                  market.latitude,
                                  market.longitude,
                                ),
                                width: 70,
                                height: 70,
                                child: GestureDetector(
                                  onTap: () => _showMarketDetails(market),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: market.color,
                                        size: 30,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(40),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '${(market.avgFreshnessScore * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: market.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      // Legend card
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Legend',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildLegendItem(
                                  'Excellent (>80%)',
                                  AppTheme.freshGreen,
                                ),
                                _buildLegendItem(
                                  'Good (60-80%)',
                                  const Color(0xFF66BB6A),
                                ),
                                _buildLegendItem(
                                  'Caution (40-60%)',
                                  AppTheme.warningOrange,
                                ),
                                _buildLegendItem(
                                  'Avoid (<40%)',
                                  AppTheme.spoiledRed,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0077B6).withAlpha(100),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () async {
                                bool serviceEnabled =
                                    await Geolocator.isLocationServiceEnabled();
                                if (!serviceEnabled) return;
                                LocationPermission permission =
                                    await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission =
                                      await Geolocator.requestPermission();
                                  if (permission == LocationPermission.denied) {
                                    return;
                                  }
                                }
                                if (permission ==
                                    LocationPermission.deniedForever) {
                                  return;
                                }
                                Position pos =
                                    await Geolocator.getCurrentPosition();
                                _mapController.move(
                                  LatLng(pos.latitude, pos.longitude),
                                  14.0,
                                );
                              },
                              child: const Center(
                                child: Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  LatLng _getMapCenter() {
    if (_selectedCity == 'Karachi') return const LatLng(24.8500, 67.0200);
    if (_selectedCity == 'Lahore') return const LatLng(31.5500, 74.3300);
    if (_selectedCity == 'Islamabad') return const LatLng(33.6800, 73.0500);
    if (_selectedCity == 'Rawalpindi') return const LatLng(33.6000, 73.0500);
    return const LatLng(30.3753, 69.3451); // Pakistan center
  }

  double _getMapZoom() {
    if (_selectedCity != 'all') return 12.0;
    return 5.5;
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(right: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color ?? AppTheme.primaryTeal),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
