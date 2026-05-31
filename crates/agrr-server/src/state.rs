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
    pub job_dispatcher: Arc<JobChainDispatcher>,
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
