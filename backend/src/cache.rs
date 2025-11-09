use crate::models::{ForecastMeta, RideSafetyResponse, VehicleType};
use anyhow::Result;
use redis::{aio::ConnectionManager, AsyncCommands};

pub struct CacheService {
    conn: ConnectionManager,
    ttl_seconds: u64,
    geohash_precision: usize,
}

impl CacheService {
    pub async fn new(redis_url: &str, ttl_seconds: u64, geohash_precision: usize) -> Result<Self> {
        let client = redis::Client::open(redis_url)?;
        let conn = ConnectionManager::new(client).await?;
        Ok(Self {
            conn,
            ttl_seconds,
            geohash_precision,
        })
    }

    fn generate_cache_key(&self, lat: f64, lon: f64, vehicle: VehicleType) -> String {
        let geohash = geohash::encode(geohash::Coord { x: lon, y: lat }, self.geohash_precision)
            .unwrap_or_else(|_| "default".to_string());

        format!("ride:{}:{}:v1", geohash, vehicle.as_str())
    }

    pub async fn get_cached_response(
        &mut self,
        lat: f64,
        lon: f64,
        vehicle: VehicleType,
    ) -> Result<Option<RideSafetyResponse>> {
        let key = self.generate_cache_key(lat, lon, vehicle);
        let cached: Option<String> = self.conn.get(&key).await?;

        match cached {
            Some(data) => Ok(serde_json::from_str(&data).ok()),
            None => Ok(None),
        }
    }

    pub async fn set_cached_response(
        &mut self,
        lat: f64,
        lon: f64,
        vehicle: VehicleType,
        response: &RideSafetyResponse,
    ) -> Result<()> {
        let key = self.generate_cache_key(lat, lon, vehicle);
        let data = serde_json::to_string(response)?;
        self.conn
            .set_ex::<_, _, ()>(&key, data, self.ttl_seconds)
            .await?;
        Ok(())
    }
}

pub fn generate_hints(forecast: &ForecastMeta, vehicle: VehicleType) -> Vec<String> {
    let mut hints = Vec::new();

    // Wind warnings
    if forecast.wind_kph > 40.0 {
        hints.push("Strong wind conditions".to_string());
    }

    // Precipitation warnings
    if forecast.precip_mm > 5.0 {
        hints.push("Heavy precipitation".to_string());
    } else if forecast.precip_mm > 0.0 {
        hints.push("Light rain".to_string());
    }

    // Temperature warnings
    if forecast.temperature_c < 0.0 {
        hints.push("Freezing temperature - risk of ice".to_string());
    } else if forecast.temperature_c < 5.0 {
        hints.push("Cold temperature".to_string());
    }

    // Visibility warnings
    if forecast.visibility_km < 2.0 {
        hints.push("Low visibility".to_string());
    }

    // UV warnings
    if forecast.uv_index > 7.0 {
        hints.push("High UV index".to_string());
    }

    // Vehicle-specific hints
    match vehicle {
        VehicleType::Bike => {
            if forecast.wind_kph > 30.0 {
                hints.push("Wind too strong for cycling".to_string());
            }
        }
        VehicleType::Motor => {
            if forecast.precip_mm > 0.0 && forecast.temperature_c < 5.0 {
                hints.push("Cold and wet - slippery conditions".to_string());
            }
        }
    }

    if hints.is_empty() {
        hints.push("Good conditions for riding".to_string());
    }

    hints
}

pub fn calculate_provider_score(forecast: &ForecastMeta, vehicle: VehicleType) -> f32 {
    let mut score: f32 = 100.0;

    // Wind penalty
    if forecast.wind_kph > 50.0 {
        score -= 30.0;
    } else if forecast.wind_kph > 40.0 {
        score -= 20.0;
    } else if forecast.wind_kph > 30.0 {
        score -= 10.0;
    }

    // Precipitation penalty
    if forecast.precip_mm > 10.0 {
        score -= 30.0;
    } else if forecast.precip_mm > 5.0 {
        score -= 20.0;
    } else if forecast.precip_mm > 0.0 {
        score -= 10.0;
    }

    // Temperature penalty
    if forecast.temperature_c < 0.0 {
        score -= 40.0;
    } else if forecast.temperature_c < 5.0 {
        score -= 20.0;
    }

    // Visibility penalty
    if forecast.visibility_km < 1.0 {
        score -= 30.0;
    } else if forecast.visibility_km < 2.0 {
        score -= 15.0;
    }

    // Vehicle-specific adjustments
    match vehicle {
        VehicleType::Bike => {
            if forecast.wind_kph > 25.0 {
                score -= 15.0;
            }
        }
        VehicleType::Motor => {
            if forecast.precip_mm > 0.0 {
                score -= 5.0;
            }
        }
    }

    score.max(0.0).min(100.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_hints_good_conditions() {
        let forecast = ForecastMeta {
            temperature_c: 20.0,
            wind_kph: 10.0,
            wind_dir: "N".to_string(),
            precip_mm: 0.0,
            humidity: 50,
            condition: "Sunny".to_string(),
            condition_code: 1000,
            feels_like_c: 20.0,
            uv_index: 5.0,
            visibility_km: 10.0,
        };

        let hints = generate_hints(&forecast, VehicleType::Bike);
        assert!(hints.contains(&"Good conditions for riding".to_string()));
    }

    #[test]
    fn test_generate_hints_bad_conditions() {
        let forecast = ForecastMeta {
            temperature_c: -5.0,
            wind_kph: 50.0,
            wind_dir: "N".to_string(),
            precip_mm: 10.0,
            humidity: 90,
            condition: "Heavy rain".to_string(),
            condition_code: 1189,
            feels_like_c: -10.0,
            uv_index: 1.0,
            visibility_km: 1.0,
        };

        let hints = generate_hints(&forecast, VehicleType::Bike);
        assert!(hints.len() > 1);
        assert!(hints.iter().any(|h| h.contains("Strong wind")));
        assert!(hints.iter().any(|h| h.contains("Heavy precipitation")));
        assert!(hints.iter().any(|h| h.contains("Freezing")));
    }

    #[test]
    fn test_calculate_provider_score() {
        let good_forecast = ForecastMeta {
            temperature_c: 20.0,
            wind_kph: 10.0,
            wind_dir: "N".to_string(),
            precip_mm: 0.0,
            humidity: 50,
            condition: "Sunny".to_string(),
            condition_code: 1000,
            feels_like_c: 20.0,
            uv_index: 5.0,
            visibility_km: 10.0,
        };

        let score = calculate_provider_score(&good_forecast, VehicleType::Bike);
        assert!(score > 90.0);

        let bad_forecast = ForecastMeta {
            temperature_c: -5.0,
            wind_kph: 50.0,
            wind_dir: "N".to_string(),
            precip_mm: 10.0,
            humidity: 90,
            condition: "Heavy rain".to_string(),
            condition_code: 1189,
            feels_like_c: -10.0,
            uv_index: 1.0,
            visibility_km: 1.0,
        };

        let score = calculate_provider_score(&bad_forecast, VehicleType::Bike);
        assert!(score < 50.0);
    }
}
