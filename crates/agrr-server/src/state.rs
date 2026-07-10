use crate::cable::CableHub;
use crate::farm_weather_fetch_locks::FarmWeatherFetchLocks;
use crate::plan_task_schedule_regen_locks::PlanTaskScheduleRegenLocks;
use crate::jobs::JobChainDispatcher;
use std::collections::HashMap;
use std::sync::Mutex;
use crate::locale_catalog::{locales_dir_from_env, LocaleCatalog};
use crate::locale_translator::LocaleTranslator;
use crate::request_locale::locale_from_headers;
use crate::runtime_env;
use agrr_adapters_sqlite::{PredictedWeatherGatewayBundle, SqlitePool, WeatherDataGatewayBundle};
use agrr_domain::weather_data::gateways::WeatherDataGateway;
use axum::http::HeaderMap;
use std::sync::Arc;

#[derive(Clone)]
pub struct AppState {
    pub sqlite: SqlitePool,
    /// Ruby: `CompositionRoot#weather_data_gateway` — shared for adjust read + internal weather APIs.
    pub weather_data: Arc<dyn WeatherDataGateway>,
    /// Predicted weather metadata (SQLite) + payload store (GCS/local FS).
    pub predicted_weather: PredictedWeatherGatewayBundle,
    pub google_client_id: Arc<String>,
    pub google_client_secret: Arc<String>,
    pub scheduler_auth_token: Arc<String>,
    /// Ruby: `BackdoorConfig.token` from `AGRR_BACKDOOR_TOKEN`.
    pub backdoor_token: Arc<String>,
    pub secure_cookies: bool,
    /// Farm / scheduler `FetchWeatherDataJob` chains (may be slow; must not block optimization).
    pub weather_fetch_job_dispatcher: Arc<JobChainDispatcher>,
    /// Cultivation-plan optimization chains only (`fetch_weather` → predict → optimize → finalize).
    pub optimization_chain_dispatcher: Arc<JobChainDispatcher>,
    /// Debounced task schedule regen after adjust / add_crop / remove (separate from optimization).
    pub task_schedule_regen_dispatcher: Arc<JobChainDispatcher>,
    /// Per-plan generation counter for debounce (last enqueue wins).
    pub task_schedule_regen_tokens: Arc<Mutex<HashMap<i64, u64>>>,
    /// Serializes task schedule regen jobs per `plan_id`.
    pub plan_task_schedule_regen_locks: PlanTaskScheduleRegenLocks,
    /// Serializes optimization-chain `fetch_weather` per `farm_id` (concurrent plans, same farm).
    pub farm_weather_fetch_locks: FarmWeatherFetchLocks,
    pub cable_hub: Arc<CableHub>,
    pub locale_catalog: Arc<LocaleCatalog>,
}

/// Default matches `RAILS_MAX_THREADS` in `docs/migration/app-rust-stack/PROVISIONAL-STACK.md`.
pub const DEFAULT_OPTIMIZATION_MAX_CONCURRENT_CHAINS: usize = 5;

fn optimization_max_concurrent_chains_from_env() -> usize {
    std::env::var("OPTIMIZATION_MAX_CONCURRENT_CHAINS")
        .ok()
        .and_then(|v| v.parse::<usize>().ok())
        .filter(|&n| n > 0)
        .unwrap_or(DEFAULT_OPTIMIZATION_MAX_CONCURRENT_CHAINS)
}

impl AppState {
    pub fn from_env() -> Self {
        let sqlite = SqlitePool::from_env();
        let weather_data: Arc<dyn WeatherDataGateway> = Arc::new(
            WeatherDataGatewayBundle::resolve(sqlite.clone())
                .unwrap_or_else(|e| panic!("weather data gateway bundle: {e}")),
        );
        let predicted_weather = PredictedWeatherGatewayBundle::resolve(sqlite.clone())
            .unwrap_or_else(|e| panic!("predicted weather gateway bundle: {e}"));
        let locales_dir = locales_dir_from_env();
        let locale_catalog = Arc::new(
            LocaleCatalog::load_from_dir(&locales_dir).unwrap_or_else(|e| {
                panic!(
                    "locale catalog from {}: {e}",
                    locales_dir.display()
                );
            }),
        );
        Self {
            sqlite,
            weather_data,
            predicted_weather,
            locale_catalog,
            google_client_id: Arc::new(std::env::var("GOOGLE_CLIENT_ID").unwrap_or_default()),
            google_client_secret: Arc::new(
                std::env::var("GOOGLE_CLIENT_SECRET").unwrap_or_default(),
            ),
            scheduler_auth_token: Arc::new(
                std::env::var("SCHEDULER_AUTH_TOKEN").unwrap_or_default(),
            ),
            backdoor_token: Arc::new(std::env::var("AGRR_BACKDOOR_TOKEN").unwrap_or_default()),
            secure_cookies: runtime_env::is_production(),
            weather_fetch_job_dispatcher: Arc::new(JobChainDispatcher::new()),
            optimization_chain_dispatcher: Arc::new(JobChainDispatcher::with_max_concurrent_chains(
                Some(optimization_max_concurrent_chains_from_env()),
            )),
            task_schedule_regen_dispatcher: Arc::new(JobChainDispatcher::new()),
            task_schedule_regen_tokens: Arc::new(Mutex::new(HashMap::new())),
            plan_task_schedule_regen_locks: PlanTaskScheduleRegenLocks::new(),
            farm_weather_fetch_locks: FarmWeatherFetchLocks::new(),
            cable_hub: Arc::new(CableHub::default()),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::from_env()
    }
}

impl AppState {
    /// Ruby: `BackdoorConfig.enabled?`
    pub fn backdoor_enabled(&self) -> bool {
        !self.backdoor_token.is_empty()
    }

    pub fn backdoor_token_matches(&self, provided: &str) -> bool {
        !self.backdoor_token.is_empty() && provided == self.backdoor_token.as_str()
    }

    pub fn locale_translator<'a>(&'a self, headers: &HeaderMap) -> LocaleTranslator<'a> {
        let locale = locale_from_headers(headers);
        LocaleTranslator::new(&self.locale_catalog, locale)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::{test_app_state, test_pool_with_plan};

    /// AppState wiring only (`jobs` covers dispatcher concurrency).
    #[test]
    fn weather_and_optimization_dispatchers_are_distinct_instances() {
        let state = test_app_state(test_pool_with_plan(1).pool);
        assert!(
            !Arc::ptr_eq(
                &state.weather_fetch_job_dispatcher,
                &state.optimization_chain_dispatcher
            ),
            "AppState must wire separate dispatchers"
        );
    }
}
