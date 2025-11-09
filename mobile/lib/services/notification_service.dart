import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/weather_models.dart';
import '../services/weather_service.dart';
import '../services/storage_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  static Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
  }) async {
    await _notifications.zonedSchedule(
      0,
      'Meteoride Morning Check',
      'Checking weather conditions...',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_weather',
          'Daily Weather',
          channelDescription: 'Daily weather notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static Future<void> showWeatherNotification({
    required bool isSafe,
    required VehicleType vehicle,
    required String weatherSummary,
  }) async {
    final title = isSafe
        ? '✓ Good to ride your ${vehicle.displayName.toLowerCase()}'
        : '⚠ Consider alternative transport';

    await _notifications.show(
      1,
      title,
      weatherSummary,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weather_alerts',
          'Weather Alerts',
          channelDescription: 'Weather condition alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  static Future<void> checkAndNotify() async {
    final storage = StorageService();
    final weather = WeatherService();

    final vehicle = await storage.getVehicleType();
    final location = await storage.getLocation();
    final rules = await storage.getSafetyRules(vehicle);

    if (location == null) return;

    try {
      final response = await weather.getRideSafety(
        latitude: location.$1,
        longitude: location.$2,
        vehicle: vehicle,
      );

      final isSafe = rules.isSafe(response.forecastMeta);
      final summary = response.hints.join(', ');

      await showWeatherNotification(
        isSafe: isSafe,
        vehicle: vehicle,
        weatherSummary: summary,
      );
    } catch (e) {
      // Handle error silently or log
    }
  }
}
