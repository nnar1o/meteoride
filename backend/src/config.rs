use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct Config {
    pub server: ServerConfig,
    pub weatherapi: WeatherApiConfig,
    pub cache: CacheConfig,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Clone, Deserialize)]
pub struct WeatherApiConfig {
    pub key: String,
    pub provider: String,
    pub base_url: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CacheConfig {
    pub redis_url: String,
    pub ttl_seconds: u64,
    pub geohash_precision: usize,
}

impl Config {
    pub fn from_file(path: &str) -> anyhow::Result<Self> {
        let contents = std::fs::read_to_string(path)?;
        let contents = shellexpand::env(&contents)?;
        let config: Config = serde_yaml::from_str(&contents)?;
        Ok(config)
    }
}
