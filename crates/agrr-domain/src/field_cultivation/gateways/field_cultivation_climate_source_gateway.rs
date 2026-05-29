use crate::field_cultivation::dtos::{
    FieldCultivationClimateSourceSnapshot, FieldCultivationPlanAccessSnapshot,
    WeatherPredictionTargets,
};

/// Ruby: `FieldCultivationClimateSourceGateway`
pub trait FieldCultivationClimateSourceGateway: Send + Sync {
    fn find_plan_access_snapshot_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationPlanAccessSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn find_climate_source_snapshot_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationClimateSourceSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn find_weather_prediction_targets_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<WeatherPredictionTargets, Box<dyn std::error::Error + Send + Sync>>;
}
