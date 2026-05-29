//! P6 entrypoint — strangler routes are added per BC when Ruby P4 + R4 gates pass.

mod composition;

use axum::{routing::get, Router};
use std::net::SocketAddr;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let app = Router::new()
        .route("/health", get(health))
        .merge(composition::api_routes())
        .with_state(composition::AppState::default());

    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));
    tracing::info!("agrr-server listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.expect("bind");
    axum::serve(listener, app).await.expect("serve");
}

async fn health() -> &'static str {
    "ok"
}
