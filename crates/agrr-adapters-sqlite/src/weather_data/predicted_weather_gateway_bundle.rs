//! Resolves predicted weather metadata (SQLite) + payload store (GCS/local FS).

use std::sync::Arc;

use agrr_adapters_gcs::PredictedWeatherGcsStoreGateway;
use agrr_domain::weather_data::gateways::{
    PredictedWeatherMetadataGateway, PredictedWeatherStoreGateway,
};

use super::predicted_weather_metadata_gateway::PredictedWeatherMetadataSqliteGateway;
use crate::pool::SqlitePool;

#[derive(Clone)]
pub struct PredictedWeatherGatewayBundle {
    pub metadata: Arc<dyn PredictedWeatherMetadataGateway>,
    pub store: Arc<dyn PredictedWeatherStoreGateway>,
}

impl PredictedWeatherGatewayBundle {
    pub fn resolve(pool: SqlitePool) -> Result<Self, String> {
        let metadata: Arc<dyn PredictedWeatherMetadataGateway> =
            Arc::new(PredictedWeatherMetadataSqliteGateway::new(pool.clone()));
        let store_impl = PredictedWeatherGcsStoreGateway::from_env()
            .map_err(|e| e.to_string())?;
        let store: Arc<dyn PredictedWeatherStoreGateway> = Arc::new(store_impl);
        Ok(Self { metadata, store })
    }
}
