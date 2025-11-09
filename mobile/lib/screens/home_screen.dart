import 'package:flutter/material.dart';
import '../models/weather_models.dart';
import '../services/weather_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final StorageService _storageService = StorageService();
  
  RideSafetyResponse? _currentWeather;
  bool _isLoading = false;
  String? _error;
  VehicleType _selectedVehicle = VehicleType.bike;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final vehicle = await _storageService.getVehicleType();
    final location = await _storageService.getLocation();
    
    setState(() {
      _selectedVehicle = vehicle;
      if (location != null) {
        _latitude = location.$1;
        _longitude = location.$2;
      }
    });

    if (_latitude != null && _longitude != null) {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    if (_latitude == null || _longitude == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _weatherService.getRideSafety(
        latitude: _latitude!,
        longitude: _longitude!,
        vehicle: _selectedVehicle,
      );

      setState(() {
        _currentWeather = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch weather: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meteoride'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              _loadSettings();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWeather,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchWeather,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchWeather,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentWeather == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_outlined, size: 64),
            const SizedBox(height: 16),
            const Text('No weather data available'),
            const SizedBox(height: 8),
            const Text('Set your location in settings'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );
    }

    return _buildWeatherDisplay();
  }

  Widget _buildWeatherDisplay() {
    final weather = _currentWeather!;
    final forecast = weather.forecastMeta;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '${forecast.temperatureC.toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                Text(
                  forecast.condition,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Feels like ${forecast.feelsLikeC.toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(),
                _buildDetailRow('Wind', '${forecast.windKph} km/h ${forecast.windDir}'),
                _buildDetailRow('Precipitation', '${forecast.precipMm} mm'),
                _buildDetailRow('Humidity', '${forecast.humidity}%'),
                _buildDetailRow('Visibility', '${forecast.visibilityKm} km'),
                _buildDetailRow('UV Index', forecast.uvIndex.toStringAsFixed(1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (weather.hints.isNotEmpty)
          Card(
            color: weather.providerScore != null && weather.providerScore! < 50
                ? Colors.red.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        weather.providerScore != null && weather.providerScore! < 50
                            ? Icons.warning
                            : Icons.check_circle,
                        color: weather.providerScore != null && weather.providerScore! < 50
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Conditions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const Divider(),
                  ...weather.hints.map((hint) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 8),
                            const SizedBox(width: 8),
                            Expanded(child: Text(hint)),
                          ],
                        ),
                      )),
                  if (weather.providerScore != null) ...[
                    const Divider(),
                    Text(
                      'Safety Score: ${weather.providerScore!.toStringAsFixed(0)}/100',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
