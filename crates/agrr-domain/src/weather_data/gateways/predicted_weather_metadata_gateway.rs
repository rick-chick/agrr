//! SQLite metadata for predicted weather cache.

use crate::weather_data::dtos::{PredictedWeatherMetadata, PredictedWeatherScope};

pub trait PredictedWeatherMetadataGateway: Send + Sync {
    fn find(
        &self,
        scope: PredictedWeatherScope,
        scope_id: i64,
    ) -> Result<Option<PredictedWeatherMetadata>, Box<dyn std::error::Error + Send + Sync>>;

    fn upsert(
        &self,
        metadata: &PredictedWeatherMetadata,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn copy_plan_metadata(
        &self,
        from_plan_id: i64,
        to_plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
