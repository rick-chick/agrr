//! P6 `agrr-server` binary entrypoint.

#[tokio::main]
async fn main() {
    agrr_adapters_gcs::preload_blocking_http_client();
    agrr_server::run_http_server().await;
}
