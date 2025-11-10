mod cache;
mod config;
mod handlers;
mod models;
mod weather;

use actix_web::{middleware, web, App, HttpServer};
use handlers::{health_handler, ride_safety_handler, AppState};
use std::sync::Arc;
use tokio::sync::Mutex;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize environment variables
    dotenv::dotenv().ok();

    // Initialize logger
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));

    // Load configuration
    let config =
        config::Config::from_file("config/default.yaml").expect("Failed to load configuration");

    log::info!("Starting Meteoride Backend v{}", env!("CARGO_PKG_VERSION"));
    log::info!(
        "Server will listen on {}:{}",
        config.server.host,
        config.server.port
    );

    // Initialize weather client
    let weather_client = weather::WeatherClient::new(
        config.weatherapi.key.clone(),
        config.weatherapi.base_url.clone(),
    );

    // Initialize cache service
    let cache_service = cache::CacheService::new(
        &config.cache.redis_url,
        config.cache.ttl_seconds,
        config.cache.geohash_precision,
    )
    .await
    .expect("Failed to connect to Redis");

    let app_state = web::Data::new(AppState {
        weather_client,
        cache_service: Arc::new(Mutex::new(cache_service)),
    });

    // Start HTTP server
    let bind_address = format!("{}:{}", config.server.host, config.server.port);
    log::info!("Server running at http://{}", bind_address);

    HttpServer::new(move || {
        App::new()
            .app_data(app_state.clone())
            .wrap(middleware::Logger::default())
            .service(health_handler)
            .service(ride_safety_handler)
    })
    .bind(&bind_address)?
    .run()
    .await
}
