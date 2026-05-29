use crate::cable::CableHub;
use crate::jobs::JobChainDispatcher;
use crate::runtime_env;
use agrr_adapters_sqlite::SqlitePool;
use std::sync::Arc;

#[derive(Clone)]
pub struct AppState {
    pub sqlite: SqlitePool,
    pub google_client_id: Arc<String>,
    pub google_client_secret: Arc<String>,
    pub scheduler_auth_token: Arc<String>,
    pub secure_cookies: bool,
    pub job_dispatcher: Arc<JobChainDispatcher>,
    pub cable_hub: Arc<CableHub>,
}

impl AppState {
    pub fn from_env() -> Self {
        Self {
            sqlite: SqlitePool::from_env(),
            google_client_id: Arc::new(std::env::var("GOOGLE_CLIENT_ID").unwrap_or_default()),
            google_client_secret: Arc::new(
                std::env::var("GOOGLE_CLIENT_SECRET").unwrap_or_default(),
            ),
            scheduler_auth_token: Arc::new(
                std::env::var("SCHEDULER_AUTH_TOKEN").unwrap_or_default(),
            ),
            secure_cookies: runtime_env::is_production(),
            job_dispatcher: Arc::new(JobChainDispatcher::new()),
            cable_hub: Arc::new(CableHub::default()),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::from_env()
    }
}
