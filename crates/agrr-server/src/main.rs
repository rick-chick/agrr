//! P6 `agrr-server` — strangler edge (Axum).

mod add_crop_support;
mod adapters;
mod plan_allocation_candidates;
mod api_keys;
mod auth;
mod auth_api;
mod auth_return_to;
mod auth_test;
mod cable;
mod contact_messages;
mod deletion_undo;
mod masters_pests;
mod masters_fertilizes;
mod masters_pesticides;
mod masters_agricultural_tasks;
mod masters_interaction_rules;
mod masters_crop_stages;
mod masters_crop_requirements;
mod entry_schedule;
mod cultivation_plans;
mod cultivation_plans_mutations;
mod field_cultivation_climate;
mod field_cultivations;
mod jobs;
mod optimization_job_chain;
mod masters_crops;
mod masters_farms;
mod masters_fields;
mod masters_json;
mod plans;
mod public_plans;
mod public_plan_save;
mod task_schedules;
mod task_schedule_timeline_json;
mod workbench_payload;
mod fallback;
mod routes;
mod runtime_env;
mod session_auth;
mod state;

use axum::{routing::get, Router};
use axum::http::{HeaderValue, Method};
use state::AppState;
use std::net::SocketAddr;
use tower_http::cors::{AllowHeaders, CorsLayer};
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    runtime_env::ensure_default_runtime_env();

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

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
        .merge(cultivation_plans::routes())
        .merge(cultivation_plans_mutations::mutation_routes())
        .merge(field_cultivations::routes())
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
