import 'package:flutter_test/flutter_test.dart';
import 'package:meteoride/models/weather_models.dart';

void main() {
  group('ForecastMeta', () {
    test('fromJson creates valid object', () {
      final json = {
        'temperature_c': 20.5,
        'wind_kph': 15.0,
        'wind_dir': 'N',
        'precip_mm': 0.0,
        'humidity': 50,
        'condition': 'Sunny',
        'condition_code': 1000,
        'feels_like_c': 19.0,
        'uv_index': 5.0,
        'visibility_km': 10.0,
      };

      final forecast = ForecastMeta.fromJson(json);

      expect(forecast.temperatureC, 20.5);
      expect(forecast.windKph, 15.0);
      expect(forecast.condition, 'Sunny');
    });
  });

  group('SafetyRules', () {
    test('defaultForBike creates valid rules', () {
      final rules = SafetyRules.defaultForBike();
      expect(rules.maxWindKph, 30.0);
      expect(rules.maxPrecipMm, 5.0);
    });

    test('defaultForMotor creates valid rules', () {
      final rules = SafetyRules.defaultForMotor();
      expect(rules.maxWindKph, 40.0);
      expect(rules.maxPrecipMm, 10.0);
    });

    test('isSafe returns true for good conditions', () {
      final rules = SafetyRules.defaultForBike();
      final forecast = ForecastMeta(
        temperatureC: 20.0,
        windKph: 15.0,
        windDir: 'N',
        precipMm: 0.0,
        humidity: 50,
        condition: 'Sunny',
        conditionCode: 1000,
        feelsLikeC: 20.0,
        uvIndex: 5.0,
        visibilityKm: 10.0,
      );

      expect(rules.isSafe(forecast), true);
    });

    test('isSafe returns false for bad conditions', () {
      final rules = SafetyRules.defaultForBike();
      final forecast = ForecastMeta(
        temperatureC: 20.0,
        windKph: 50.0, // Too high
        windDir: 'N',
        precipMm: 0.0,
        humidity: 50,
        condition: 'Windy',
        conditionCode: 1000,
        feelsLikeC: 20.0,
        uvIndex: 5.0,
        visibilityKm: 10.0,
      );

      expect(rules.isSafe(forecast), false);
    });

    test('toJson and fromJson roundtrip', () {
      final original = SafetyRules.defaultForBike();
      final json = original.toJson();
      final restored = SafetyRules.fromJson(json);

      expect(restored.maxWindKph, original.maxWindKph);
      expect(restored.maxPrecipMm, original.maxPrecipMm);
      expect(restored.minTemperatureC, original.minTemperatureC);
    });
  });

  group('VehicleType', () {
    test('displayName returns correct values', () {
      expect(VehicleType.bike.displayName, 'Bike');
      expect(VehicleType.motor.displayName, 'Motorcycle');
    });

    test('apiValue returns correct values', () {
      expect(VehicleType.bike.apiValue, 'bike');
      expect(VehicleType.motor.apiValue, 'motor');
    });
  });
}
