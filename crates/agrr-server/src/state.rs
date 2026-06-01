use crate::cable::CableHub;
use crate::jobs::JobChainDispatcher;
use crate::locale_catalog::{locales_dir_from_env, LocaleCatalog};
use crate::locale_translator::LocaleTranslator;
use crate::request_locale::locale_from_headers;
use crate::runtime_env;
use crate::weather_data_gateway_factory::WeatherDataGatewayBundle;
use agrr_adapters_sqlite::SqlitePool;
use agrr_domain::weather_data::gateways::WeatherDataGateway;
use axum::http::HeaderMap;
use std::sync::Arc;

#[derive(Clone)]
pub struct AppState {
    pub sqlite: SqlitePool,
    /// Ruby: `CompositionRoot#weather_data_gateway` — shared for adjust read + internal weather APIs.
    pub weather_data: Arc<dyn WeatherDataGateway>,
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
    pub cable_hub: Arc<CableHub>,
    pub locale_catalog: Arc<LocaleCatalog>,
}

impl AppState {
    pub fn from_env() -> Self {
        let sqlite = SqlitePool::from_env();
        let weather_data: Arc<dyn WeatherDataGateway> = Arc::new(
            WeatherDataGatewayBundle::resolve(sqlite.clone())
                .unwrap_or_else(|e| panic!("weather data gateway bundle: {e}")),
        );
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
            optimization_chain_dispatcher: Arc::new(JobChainDispatcher::new()),
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
    use crate::jobs::JobStep;
    use crate::optimization_chain_phase::advance_phase;
    use crate::test_support::{read_optimization_phase, test_app_state, test_pool_with_plan, wait_until};
    use agrr_domain::cultivation_plan::dtos::CultivationPlanPhaseName;

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

    #[test]
    fn slow_weather_fetch_does_not_block_optimization_dispatcher_queue() {
        let db = test_pool_with_plan(1);
        let pool = db.pool.clone();
        let state = test_app_state(db.pool);
        let channel = "PublicPlanChannel";

        advance_phase(
            &state,
            1,
            channel,
            CultivationPlanPhaseName::StartOptimizing,
            None,
        )
        .expect("start optimizing");
        assert_eq!(
            read_optimization_phase(&pool, 1).as_deref(),
            Some("initializing")
        );

        state.weather_fetch_job_dispatcher.enqueue_chain(vec![JobStep {
            name: "scheduler_fetch_weather_data",
            run: Arc::new(|| {
                Box::pin(async {
                    tokio::time::sleep(std::time::Duration::from_millis(2_000)).await;
                    true
                })
            }),
        }]);

        let state_for_fetch = state.clone();
        state.optimization_chain_dispatcher.enqueue_chain(vec![JobStep {
            name: "fetch_weather_data",
            run: Arc::new(move || {
                let state = state_for_fetch.clone();
                Box::pin(async move {
                    advance_phase(
                        &state,
                        1,
                        channel,
                        CultivationPlanPhaseName::PhaseFetchingWeather,
                        None,
                    )
                    .expect("fetching weather phase");
                    true
                })
            }),
        }]);

        assert!(
            wait_until(std::time::Duration::from_millis(500), || {
                read_optimization_phase(&pool, 1).as_deref() == Some("fetching_weather")
            }),
            "optimization queue must run while weather queue is busy; phase={:?}",
            read_optimization_phase(&pool, 1)
        );
    }
}
