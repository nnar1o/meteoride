use crate::models::{ForecastMeta, WeatherApiResponse};
use anyhow::Result;

pub struct WeatherClient {
    api_key: String,
    base_url: String,
    client: reqwest::Client,
}

impl WeatherClient {
    pub fn new(api_key: String, base_url: String) -> Self {
        Self {
            api_key,
            base_url,
            client: reqwest::Client::new(),
        }
    }

    pub async fn get_current_weather(&self, lat: f64, lon: f64) -> Result<ForecastMeta> {
        let url = format!(
            "{}/current.json?key={}&q={},{}",
            self.base_url, self.api_key, lat, lon
        );

        let response = self
            .client
            .get(&url)
            .send()
            .await?
            .json::<WeatherApiResponse>()
            .await?;

        Ok(ForecastMeta {
            temperature_c: response.current.temp_c,
            wind_kph: response.current.wind_kph,
            wind_dir: response.current.wind_dir,
            precip_mm: response.current.precip_mm,
            humidity: response.current.humidity,
            condition: response.current.condition.text,
            condition_code: response.current.condition.code,
            feels_like_c: response.current.feelslike_c,
            uv_index: response.current.uv,
            visibility_km: response.current.vis_km,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_weather_client_creation() {
        let client = WeatherClient::new(
            "test_key".to_string(),
            "https://api.weatherapi.com/v1".to_string(),
        );
        assert_eq!(client.api_key, "test_key");
    }
}
