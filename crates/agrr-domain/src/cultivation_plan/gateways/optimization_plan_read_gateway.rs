//! Ruby: `Domain::CultivationPlan::Gateways::OptimizationPlanReadGateway`

use crate::cultivation_plan::dtos::OptimizationPlanReadPlanCoreSnapshot;
use crate::weather_data::dtos::{FarmWeatherPrediction, WeatherLocation};

/// Ruby: `Domain::CultivationPlan::Gateways::OptimizationPlanReadGateway`
pub trait OptimizationPlanReadGateway: Send + Sync {
    fn find_optimization_plan_core_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<OptimizationPlanReadPlanCoreSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn find_optimization_weather_location_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Option<WeatherLocation>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_optimization_farm_weather_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Option<FarmWeatherPrediction>, Box<dyn std::error::Error + Send + Sync>>;
}
