//! P6 `agrr-server` binary entrypoint.

#[tokio::main]
async fn main() {
    agrr_server::run_http_server().await;
}
