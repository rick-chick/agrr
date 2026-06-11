use serde_json::Value;
use time::Date;

use crate::weather_data::dtos::PredictedWeatherMetadata;

/// Plan-scoped predicted weather persistence (metadata + GCS payload).
pub trait FieldCultivationPlanPredictedWeatherGateway: Send + Sync {
    fn find_plan_metadata(
        &self,
        plan_id: i64,
    ) -> Result<Option<PredictedWeatherMetadata>, Box<dyn std::error::Error + Send + Sync>>;

    fn persist_plan_prediction(
        &self,
        plan_id: i64,
        payload: &Value,
        target_end_date: Date,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
