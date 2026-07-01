//! P6 `agrr-server` — strangler edge (Axum).

pub mod adapters;
pub mod locale_catalog;
pub mod locale_translator;
pub mod request_locale;
pub mod add_crop_support;
pub mod adjust_weather_prediction;
pub mod cultivation_plan_optimize;
pub mod cultivation_plan_weather_load;
pub mod ai_api;
pub mod fertilize_ai_adapters;
pub mod pest_ai_adapters;
pub mod api_keys;
pub mod auth;
pub mod backdoor;
pub mod auth_api;
pub mod auth_return_to;
pub mod auth_test;
pub mod cable;
pub mod contact_messages;
pub mod cultivation_plans;
pub mod cultivation_plans_mutations;
pub mod deletion_undo;
pub mod entry_schedule;
pub mod fallback;
pub mod field_cultivation_climate;
pub mod farm_weather_fetch;
pub mod farm_weather_fetch_locks;
pub mod field_cultivations;
pub mod internal_farms;
pub mod jobs;
pub mod masters_auth;
pub mod masters_agricultural_tasks;
pub mod masters_crop_requirements;
pub mod masters_crop_agricultural_tasks;
pub mod masters_crop_context;
pub mod masters_crop_pests;
pub mod masters_crop_pesticides;
pub mod masters_crop_stages;
pub mod masters_crops;
pub mod masters_farms;
pub mod masters_fields;
pub mod masters_fertilizes;
pub mod masters_interaction_rules;
pub mod masters_json;
pub mod masters_pests;
pub mod masters_pesticides;
pub mod optimization_chain_phase;
pub mod optimization_chain_run;
mod optimization_chain_telemetry;
pub mod optimization_job_chain;
#[cfg(test)]
mod test_support;
pub mod plan_allocation_adjust_debug_dump;
pub mod plan_allocation_candidates;
pub mod plans;
pub mod public_plan_save;
pub mod public_plans;
pub mod routes;
pub mod scheduler_weather_update;
pub mod runtime_env;
pub mod session_auth;
pub mod state;
pub mod task_schedule_generation;
pub mod task_schedule_timeline_json;
pub mod task_schedules;
pub mod work_records;
pub mod work_hub;
pub mod weather_prediction_anchors;
pub mod workbench_payload;

use axum::http::{HeaderValue, Method};
use axum::{routing::get, Router};
use state::AppState;
use std::net::SocketAddr;
use tower_http::cors::{AllowHeaders, CorsLayer};
use tracing_subscriber::EnvFilter;

pub async fn run_http_server() {
    runtime_env::ensure_default_runtime_env();

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    if let Err(message) = agrr_adapters_sqlite::validate_weather_storage_config() {
        panic!("weather storage configuration invalid: {message}");
    }

    let state = AppState::from_env();

    let cors = CorsLayer::new()
        .allow_credentials(true)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::PATCH,
            Method::DELETE,
            Method::OPTIONS,
            Method::HEAD,
        ])
        .allow_headers(AllowHeaders::mirror_request())
        .allow_origin(parse_cors_origins());

    let app = Router::new()
        .route("/health", get(|| async { "ok" }))
        .route("/up", get(|| async { "ok" }))
        .merge(auth::routes())
        .merge(auth_api::routes())
        .merge(cable::routes())
        .merge(plans::routes())
        .merge(task_schedules::routes())
        .merge(work_records::routes())
        .merge(work_hub::routes())
        .merge(cultivation_plans::routes())
        .merge(cultivation_plans_mutations::mutation_routes())
        .merge(field_cultivations::routes())
        .merge(field_cultivations::public_routes())
        .merge(field_cultivation_climate::climate_routes(true))
        .merge(public_plans::routes())
        .merge(public_plan_save::routes())
        .merge(deletion_undo::routes())
        .merge(entry_schedule::routes())
        .merge(field_cultivation_climate::climate_routes(false))
        .merge(masters_farms::routes())
        .merge(masters_fields::routes())
        .merge(masters_crops::routes())
        .merge(masters_crop_stages::routes())
        .merge(masters_crop_pests::routes())
        .merge(masters_crop_agricultural_tasks::routes())
        .merge(masters_crop_pesticides::routes())
        .merge(masters_crop_requirements::routes())
        .merge(masters_pests::routes())
        .merge(masters_fertilizes::routes())
        .merge(masters_pesticides::routes())
        .merge(masters_agricultural_tasks::routes())
        .merge(masters_interaction_rules::routes())
        .merge(contact_messages::routes())
        .merge(api_keys::routes())
        .merge(auth_test::routes())
        .merge(routes::api_routes())
        .merge(internal_farms::routes())
        .merge(ai_api::routes())
        .merge(backdoor::routes::routes())
        .fallback(fallback::api_not_migrated)
        .layer(cors)
        .with_state(state);

    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8080);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("agrr-server listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.expect("bind");
    axum::serve(listener, app).await.expect("serve");
}

fn parse_cors_origins() -> Vec<HeaderValue> {
    let mut origins: Vec<String> = vec![
        "http://localhost:4200".into(),
        "http://localhost:4201".into(),
        "http://127.0.0.1:4200".into(),
        "http://127.0.0.1:4201".into(),
    ];
    if let Ok(extra) = std::env::var("CORS_ALLOWED_ORIGINS") {
        for part in extra.split(',') {
            let part = part.trim();
            if !part.is_empty() {
                origins.push(part.to_string());
            }
        }
    }
    origins
        .into_iter()
        .filter_map(|o| o.parse().ok())
        .collect()
}
