class ForecastMeta {
  final double temperatureC;
  final double windKph;
  final String windDir;
  final double precipMm;
  final int humidity;
  final String condition;
  final int conditionCode;
  final double feelsLikeC;
  final double uvIndex;
  final double visibilityKm;

  ForecastMeta({
    required this.temperatureC,
    required this.windKph,
    required this.windDir,
    required this.precipMm,
    required this.humidity,
    required this.condition,
    required this.conditionCode,
    required this.feelsLikeC,
    required this.uvIndex,
    required this.visibilityKm,
  });

  factory ForecastMeta.fromJson(Map<String, dynamic> json) {
    return ForecastMeta(
      temperatureC: (json['temperature_c'] as num).toDouble(),
      windKph: (json['wind_kph'] as num).toDouble(),
      windDir: json['wind_dir'] as String,
      precipMm: (json['precip_mm'] as num).toDouble(),
      humidity: json['humidity'] as int,
      condition: json['condition'] as String,
      conditionCode: json['condition_code'] as int,
      feelsLikeC: (json['feels_like_c'] as num).toDouble(),
      uvIndex: (json['uv_index'] as num).toDouble(),
      visibilityKm: (json['visibility_km'] as num).toDouble(),
    );
  }
}

class RideSafetyResponse {
  final ForecastMeta forecastMeta;
  final List<String> hints;
  final double? providerScore;

  RideSafetyResponse({
    required this.forecastMeta,
    required this.hints,
    this.providerScore,
  });

  factory RideSafetyResponse.fromJson(Map<String, dynamic> json) {
    return RideSafetyResponse(
      forecastMeta: ForecastMeta.fromJson(json['forecast_meta']),
      hints: List<String>.from(json['hints']),
      providerScore: json['provider_score']?.toDouble(),
    );
  }
}

enum VehicleType {
  bike,
  motor;

  String get displayName {
    switch (this) {
      case VehicleType.bike:
        return 'Bike';
      case VehicleType.motor:
        return 'Motorcycle';
    }
  }

  String get apiValue {
    switch (this) {
      case VehicleType.bike:
        return 'bike';
      case VehicleType.motor:
        return 'motor';
    }
  }
}

class SafetyRules {
  final double maxWindKph;
  final double maxPrecipMm;
  final double minTemperatureC;
  final double minVisibilityKm;
  final double maxUvIndex;

  SafetyRules({
    required this.maxWindKph,
    required this.maxPrecipMm,
    required this.minTemperatureC,
    required this.minVisibilityKm,
    required this.maxUvIndex,
  });

  factory SafetyRules.defaultForBike() {
    return SafetyRules(
      maxWindKph: 30.0,
      maxPrecipMm: 5.0,
      minTemperatureC: 5.0,
      minVisibilityKm: 2.0,
      maxUvIndex: 8.0,
    );
  }

  factory SafetyRules.defaultForMotor() {
    return SafetyRules(
      maxWindKph: 40.0,
      maxPrecipMm: 10.0,
      minTemperatureC: 0.0,
      minVisibilityKm: 1.5,
      maxUvIndex: 10.0,
    );
  }

  factory SafetyRules.fromJson(Map<String, dynamic> json) {
    return SafetyRules(
      maxWindKph: (json['max_wind_kph'] as num).toDouble(),
      maxPrecipMm: (json['max_precip_mm'] as num).toDouble(),
      minTemperatureC: (json['min_temperature_c'] as num).toDouble(),
      minVisibilityKm: (json['min_visibility_km'] as num).toDouble(),
      maxUvIndex: (json['max_uv_index'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_wind_kph': maxWindKph,
      'max_precip_mm': maxPrecipMm,
      'min_temperature_c': minTemperatureC,
      'min_visibility_km': minVisibilityKm,
      'max_uv_index': maxUvIndex,
    };
  }

  bool isSafe(ForecastMeta forecast) {
    return forecast.windKph <= maxWindKph &&
        forecast.precipMm <= maxPrecipMm &&
        forecast.temperatureC >= minTemperatureC &&
        forecast.visibilityKm >= minVisibilityKm &&
        forecast.uvIndex <= maxUvIndex;
  }
}
