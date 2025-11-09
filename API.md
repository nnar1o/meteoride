# Meteoride API Documentation

## Base URL
```
http://localhost:8080
```

## Endpoints

### Health Check

```http
GET /health
```

Returns the health status of the backend service.

**Response:**
```json
{
  "status": "ok",
  "version": "0.1.1"
}
```

---

### Ride Safety Assessment

```http
GET /v1/ride-safety
```

Returns weather data and safety hints for riding.

**Query Parameters:**

| Parameter | Type   | Required | Description                          |
|-----------|--------|----------|--------------------------------------|
| lat       | float  | Yes      | Latitude (-90 to 90)                |
| lon       | float  | Yes      | Longitude (-180 to 180)             |
| vehicle   | string | Yes      | Vehicle type: `bike` or `motor`     |

**Example Request:**
```bash
curl "http://localhost:8080/v1/ride-safety?lat=52.52&lon=13.405&vehicle=bike"
```

**Success Response (200 OK):**
```json
{
  "forecast_meta": {
    "temperature_c": 15.5,
    "wind_kph": 20.0,
    "wind_dir": "NW",
    "precip_mm": 0.0,
    "humidity": 65,
    "condition": "Partly cloudy",
    "condition_code": 1003,
    "feels_like_c": 14.2,
    "uv_index": 4.0,
    "visibility_km": 10.0
  },
  "hints": [
    "Good conditions for riding"
  ],
  "provider_score": 85.0
}
```

**Error Response (400 Bad Request):**
```json
{
  "error": "Invalid vehicle type. Use 'bike' or 'motor'"
}
```

**Error Response (500 Internal Server Error):**
```json
{
  "error": "Failed to fetch weather data"
}
```

---

## Data Models

### ForecastMeta

Weather forecast metadata.

| Field           | Type   | Description                        |
|-----------------|--------|------------------------------------|
| temperature_c   | float  | Temperature in Celsius            |
| wind_kph        | float  | Wind speed in km/h                |
| wind_dir        | string | Wind direction (N, NE, E, etc.)   |
| precip_mm       | float  | Precipitation in millimeters      |
| humidity        | int    | Humidity percentage (0-100)       |
| condition       | string | Weather condition description     |
| condition_code  | int    | Weather condition code            |
| feels_like_c    | float  | "Feels like" temperature in °C    |
| uv_index        | float  | UV index                          |
| visibility_km   | float  | Visibility in kilometers          |

### Hints

An array of strings describing weather conditions that may affect ride safety:

- `"Good conditions for riding"`
- `"Strong wind conditions"`
- `"Heavy precipitation"`
- `"Light rain"`
- `"Freezing temperature - risk of ice"`
- `"Cold temperature"`
- `"Low visibility"`
- `"High UV index"`
- `"Wind too strong for cycling"` (bike only)
- `"Cold and wet - slippery conditions"` (motor only)

### Provider Score

A numerical score (0-100) indicating overall safety:
- **80-100**: Excellent conditions
- **60-79**: Good conditions
- **40-59**: Moderate conditions, caution advised
- **20-39**: Poor conditions
- **0-19**: Dangerous conditions

---

## Caching

The backend uses Redis caching with:
- **TTL**: 15 minutes (configurable)
- **Key format**: `ride:{geohash}:{vehicle}:v1`
- **Geohash precision**: 5 characters (~4.9km × 4.9km)

Nearby requests are grouped using geohash to reduce API calls.

---

## Rate Limits

Rate limits depend on your WeatherAPI plan. The backend caching helps stay within limits.

---

## Error Handling

| Status Code | Description                              |
|-------------|------------------------------------------|
| 200         | Success                                  |
| 400         | Bad request (invalid parameters)         |
| 500         | Server error (API failure, etc.)         |

---

## Examples

### Check weather for cycling in Berlin
```bash
curl "http://localhost:8080/v1/ride-safety?lat=52.52&lon=13.405&vehicle=bike"
```

### Check weather for motorcycle in London
```bash
curl "http://localhost:8080/v1/ride-safety?lat=51.5074&lon=-0.1278&vehicle=motor"
```

### With jq for pretty output
```bash
curl -s "http://localhost:8080/v1/ride-safety?lat=52.52&lon=13.405&vehicle=bike" | jq
```

---

## Configuration

Backend configuration is in `backend/config/default.yaml`:

```yaml
server:
  host: "0.0.0.0"
  port: 8080

weatherapi:
  key: "${WEATHER_API_KEY}"
  provider: "WeatherAPI"
  base_url: "https://api.weatherapi.com/v1"

cache:
  redis_url: "redis://redis:6379/0"
  ttl_seconds: 900
  geohash_precision: 5
```

Environment variables can be used for sensitive values.
