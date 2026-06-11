//! GCS (or local FS mirror) for predicted weather payloads.

use serde_json::Value;

use crate::weather_data::dtos::PredictedWeatherScope;

pub trait PredictedWeatherStoreGateway: Send + Sync {
    fn read_payload(
        &self,
        scope: PredictedWeatherScope,
        scope_id: i64,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>>;

    fn write_payload(
        &self,
        scope: PredictedWeatherScope,
        scope_id: i64,
        payload: &Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn copy_plan_payload(
        &self,
        from_plan_id: i64,
        to_plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
