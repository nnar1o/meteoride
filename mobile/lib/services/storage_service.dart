import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/weather_models.dart';

class StorageService {
  static const String _vehicleTypeKey = 'vehicle_type';
  static const String _locationLatKey = 'location_lat';
  static const String _locationLonKey = 'location_lon';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationTimeKey = 'notification_time';
  static const String _safetyRulesBikeKey = 'safety_rules_bike';
  static const String _safetyRulesMotorKey = 'safety_rules_motor';

  Future<void> saveVehicleType(VehicleType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vehicleTypeKey, type.apiValue);
  }

  Future<VehicleType> getVehicleType() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_vehicleTypeKey) ?? 'bike';
    return value == 'motor' ? VehicleType.motor : VehicleType.bike;
  }

  Future<void> saveLocation(double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_locationLatKey, lat);
    await prefs.setDouble(_locationLonKey, lon);
  }

  Future<(double, double)?> getLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_locationLatKey);
    final lon = prefs.getDouble(_locationLonKey);
    if (lat != null && lon != null) {
      return (lat, lon);
    }
    return null;
  }

  Future<void> saveNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  Future<void> saveNotificationTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationTimeKey, '$hour:$minute');
  }

  Future<(int, int)> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_notificationTimeKey) ?? '7:0';
    final parts = value.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<void> saveSafetyRules(VehicleType vehicle, SafetyRules rules) async {
    final prefs = await SharedPreferences.getInstance();
    final key = vehicle == VehicleType.bike ? _safetyRulesBikeKey : _safetyRulesMotorKey;
    await prefs.setString(key, json.encode(rules.toJson()));
  }

  Future<SafetyRules> getSafetyRules(VehicleType vehicle) async {
    final prefs = await SharedPreferences.getInstance();
    final key = vehicle == VehicleType.bike ? _safetyRulesBikeKey : _safetyRulesMotorKey;
    final value = prefs.getString(key);
    
    if (value != null) {
      return SafetyRules.fromJson(json.decode(value));
    }
    
    return vehicle == VehicleType.bike
        ? SafetyRules.defaultForBike()
        : SafetyRules.defaultForMotor();
  }
}
