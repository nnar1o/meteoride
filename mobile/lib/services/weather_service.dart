import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_models.dart';

class WeatherService {
  final String baseUrl;

  WeatherService({this.baseUrl = 'http://localhost:8080'});

  Future<RideSafetyResponse> getRideSafety({
    required double latitude,
    required double longitude,
    required VehicleType vehicle,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/ride-safety').replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'vehicle': vehicle.apiValue,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return RideSafetyResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load ride safety data: ${response.statusCode}');
    }
  }
}
