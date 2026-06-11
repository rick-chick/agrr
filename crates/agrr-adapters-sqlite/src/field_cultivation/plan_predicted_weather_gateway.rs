//! Persist predicted weather on cultivation plans (metadata + GCS payload).

use std::sync::Arc;

use crate::pool::SqlitePool;
use agrr_domain::field_cultivation::gateways::FieldCultivationPlanPredictedWeatherGateway;
use agrr_domain::weather_data::dtos::{PredictedWeatherMetadata, PredictedWeatherScope};
use agrr_domain::weather_data::gateways::{
    PredictedWeatherMetadataGateway, PredictedWeatherStoreGateway,
};
use agrr_domain::weather_data::helpers::build_metadata_from_payload;
use serde_json::Value;
use time::Date;

pub struct FieldCultivationPlanPredictedWeatherSqliteGateway {
    metadata: Arc<dyn PredictedWeatherMetadataGateway>,
    store: Arc<dyn PredictedWeatherStoreGateway>,
}

impl FieldCultivationPlanPredictedWeatherSqliteGateway {
    pub fn new(
        pool: SqlitePool,
        metadata: Arc<dyn PredictedWeatherMetadataGateway>,
        store: Arc<dyn PredictedWeatherStoreGateway>,
    ) -> Self {
        let _ = pool;
        Self { metadata, store }
    }

    pub fn from_bundle(
        pool: SqlitePool,
        bundle: &crate::weather_data::PredictedWeatherGatewayBundle,
    ) -> Self {
        Self::new(pool, bundle.metadata.clone(), bundle.store.clone())
    }
}

impl FieldCultivationPlanPredictedWeatherGateway for FieldCultivationPlanPredictedWeatherSqliteGateway {
    fn find_plan_metadata(
        &self,
        plan_id: i64,
    ) -> Result<Option<PredictedWeatherMetadata>, Box<dyn std::error::Error + Send + Sync>> {
        self.metadata.find(PredictedWeatherScope::Plan, plan_id)
    }

    fn persist_plan_prediction(
        &self,
        plan_id: i64,
        payload: &Value,
        target_end_date: Date,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let generated_at = time::OffsetDateTime::now_utc().unix_timestamp().to_string();
        let metadata = build_metadata_from_payload(
            PredictedWeatherScope::Plan,
            plan_id,
            payload,
            target_end_date,
            generated_at,
        )
        .ok_or("failed to build prediction metadata")?;
        self.store
            .write_payload(PredictedWeatherScope::Plan, plan_id, payload)?;
        self.metadata.upsert(&metadata)?;
        Ok(())
    }
}
