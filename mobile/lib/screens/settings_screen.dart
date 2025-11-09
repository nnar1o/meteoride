import 'package:flutter/material.dart';
import '../models/weather_models.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  
  VehicleType _selectedVehicle = VehicleType.bike;
  bool _notificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 7, minute: 0);
  SafetyRules? _safetyRules;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final vehicle = await _storageService.getVehicleType();
    final location = await _storageService.getLocation();
    final notifEnabled = await _storageService.getNotificationsEnabled();
    final notifTime = await _storageService.getNotificationTime();
    final rules = await _storageService.getSafetyRules(vehicle);

    setState(() {
      _selectedVehicle = vehicle;
      _notificationsEnabled = notifEnabled;
      _notificationTime = TimeOfDay(hour: notifTime.$1, minute: notifTime.$2);
      _safetyRules = rules;
      
      if (location != null) {
        _latController.text = location.$1.toString();
        _lonController.text = location.$2.toString();
      }
    });
  }

  Future<void> _saveSettings() async {
    await _storageService.saveVehicleType(_selectedVehicle);
    
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat != null && lon != null) {
      await _storageService.saveLocation(lat, lon);
    }

    await _storageService.saveNotificationsEnabled(_notificationsEnabled);
    await _storageService.saveNotificationTime(
      _notificationTime.hour,
      _notificationTime.minute,
    );

    if (_safetyRules != null) {
      await _storageService.saveSafetyRules(_selectedVehicle, _safetyRules!);
    }

    if (_notificationsEnabled) {
      await NotificationService.scheduleDailyNotification(
        hour: _notificationTime.hour,
        minute: _notificationTime.minute,
      );
    } else {
      await NotificationService.cancelAll();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _selectNotificationTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );

    if (time != null) {
      setState(() {
        _notificationTime = time;
      });
    }
  }

  void _showSafetyRulesDialog() {
    if (_safetyRules == null) return;

    final maxWindController = TextEditingController(
      text: _safetyRules!.maxWindKph.toString(),
    );
    final maxPrecipController = TextEditingController(
      text: _safetyRules!.maxPrecipMm.toString(),
    );
    final minTempController = TextEditingController(
      text: _safetyRules!.minTemperatureC.toString(),
    );
    final minVisController = TextEditingController(
      text: _safetyRules!.minVisibilityKm.toString(),
    );
    final maxUvController = TextEditingController(
      text: _safetyRules!.maxUvIndex.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Safety Rules'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: maxWindController,
                decoration: const InputDecoration(
                  labelText: 'Max Wind (km/h)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: maxPrecipController,
                decoration: const InputDecoration(
                  labelText: 'Max Precipitation (mm)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: minTempController,
                decoration: const InputDecoration(
                  labelText: 'Min Temperature (°C)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: minVisController,
                decoration: const InputDecoration(
                  labelText: 'Min Visibility (km)',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: maxUvController,
                decoration: const InputDecoration(
                  labelText: 'Max UV Index',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _safetyRules = SafetyRules(
                  maxWindKph: double.parse(maxWindController.text),
                  maxPrecipMm: double.parse(maxPrecipController.text),
                  minTemperatureC: double.parse(minTempController.text),
                  minVisibilityKm: double.parse(minVisController.text),
                  maxUvIndex: double.parse(maxUvController.text),
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Type',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<VehicleType>(
                    segments: const [
                      ButtonSegment(
                        value: VehicleType.bike,
                        label: Text('Bike'),
                        icon: Icon(Icons.pedal_bike),
                      ),
                      ButtonSegment(
                        value: VehicleType.motor,
                        label: Text('Motorcycle'),
                        icon: Icon(Icons.motorcycle),
                      ),
                    ],
                    selected: {_selectedVehicle},
                    onSelectionChanged: (Set<VehicleType> newSelection) {
                      setState(() {
                        _selectedVehicle = newSelection.first;
                        _loadSettings();
                      });
                    },
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
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _lonController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
                    'Notifications',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                  if (_notificationsEnabled)
                    ListTile(
                      title: const Text('Notification Time'),
                      subtitle: Text(_notificationTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: _selectNotificationTime,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Safety Rules'),
              subtitle: const Text('Configure your safety thresholds'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showSafetyRulesDialog,
            ),
          ),
        ],
      ),
    );
  }
}
