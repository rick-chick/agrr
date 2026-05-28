use crate::field_cultivation::dtos::{
    FieldCultivationClimateSourceSnapshot, WeatherPredictionTargets,
};
use crate::field_cultivation::gateways::FieldCultivationPlanAccessGateway;

/// Ruby: `FieldCultivationClimateSourceGateway`
pub trait FieldCultivationClimateSourceGateway: FieldCultivationPlanAccessGateway {
    fn find_climate_source_snapshot_by_field_cultivation_id(
        &self,
        field_cultivation_id: i64,
    ) -> Result<FieldCultivationClimateSourceSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn find_weather_prediction_targets_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<WeatherPredictionTargets, Box<dyn std::error::Error + Send + Sync>>;
}
