use actix_web::{get, web, HttpResponse, Responder};
use crate::{
    cache::{calculate_provider_score, generate_hints, CacheService},
    models::{RideSafetyResponse, VehicleType},
    weather::WeatherClient,
};
use std::sync::Arc;
use tokio::sync::Mutex;

pub struct AppState {
    pub weather_client: WeatherClient,
    pub cache_service: Arc<Mutex<CacheService>>,
}

#[derive(serde::Deserialize)]
pub struct RideSafetyQuery {
    lat: f64,
    lon: f64,
    vehicle: String,
}

#[get("/v1/ride-safety")]
pub async fn ride_safety_handler(
    query: web::Query<RideSafetyQuery>,
    data: web::Data<AppState>,
) -> impl Responder {
    // Parse vehicle type
    let vehicle = match VehicleType::from_str(&query.vehicle) {
        Some(v) => v,
        None => {
            return HttpResponse::BadRequest().json(serde_json::json!({
                "error": "Invalid vehicle type. Use 'bike' or 'motor'"
            }));
        }
    };

    // Check cache
    let mut cache = data.cache_service.lock().await;
    if let Ok(Some(cached)) = cache.get_cached_response(query.lat, query.lon, vehicle).await {
        log::info!("Cache hit for {},{} vehicle={}", query.lat, query.lon, query.vehicle);
        return HttpResponse::Ok().json(cached);
    }
    drop(cache);

    // Fetch from weather API
    let forecast = match data.weather_client.get_current_weather(query.lat, query.lon).await {
        Ok(f) => f,
        Err(e) => {
            log::error!("Failed to fetch weather: {}", e);
            return HttpResponse::InternalServerError().json(serde_json::json!({
                "error": "Failed to fetch weather data"
            }));
        }
    };

    // Generate hints and score
    let hints = generate_hints(&forecast, vehicle);
    let provider_score = calculate_provider_score(&forecast, vehicle);

    let response = RideSafetyResponse {
        forecast_meta: forecast,
        hints,
        provider_score: Some(provider_score),
    };

    // Cache the response
    let mut cache = data.cache_service.lock().await;
    if let Err(e) = cache.set_cached_response(query.lat, query.lon, vehicle, &response).await {
        log::warn!("Failed to cache response: {}", e);
    }

    log::info!("Weather fetched for {},{} vehicle={}", query.lat, query.lon, query.vehicle);
    HttpResponse::Ok().json(response)
}

#[get("/health")]
pub async fn health_handler() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({
        "status": "ok",
        "version": env!("CARGO_PKG_VERSION")
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vehicle_type_parsing() {
        assert!(VehicleType::from_str("bike").is_some());
        assert!(VehicleType::from_str("motor").is_some());
        assert!(VehicleType::from_str("motorcycle").is_some());
        assert!(VehicleType::from_str("invalid").is_none());
    }
}
