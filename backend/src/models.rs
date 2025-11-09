use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RideSafetyResponse {
    pub forecast_meta: ForecastMeta,
    pub hints: Vec<String>,
    pub provider_score: Option<f32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ForecastMeta {
    pub temperature_c: f32,
    pub wind_kph: f32,
    pub wind_dir: String,
    pub precip_mm: f32,
    pub humidity: i32,
    pub condition: String,
    pub condition_code: i32,
    pub feels_like_c: f32,
    pub uv_index: f32,
    pub visibility_km: f32,
}

#[derive(Debug, Clone, Copy)]
pub enum VehicleType {
    Bike,
    Motor,
}

impl VehicleType {
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "bike" => Some(VehicleType::Bike),
            "motor" | "motorcycle" => Some(VehicleType::Motor),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &str {
        match self {
            VehicleType::Bike => "bike",
            VehicleType::Motor => "motor",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeatherApiResponse {
    pub current: CurrentWeather,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CurrentWeather {
    pub temp_c: f32,
    pub wind_kph: f32,
    pub wind_dir: String,
    pub precip_mm: f32,
    pub humidity: i32,
    pub condition: WeatherCondition,
    pub feelslike_c: f32,
    pub uv: f32,
    pub vis_km: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeatherCondition {
    pub text: String,
    pub code: i32,
}
