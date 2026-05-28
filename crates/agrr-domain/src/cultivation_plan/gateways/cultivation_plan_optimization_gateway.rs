//! Optimization write/read helpers on cultivation plans (Ruby: `CultivationPlanGateway` optimize section).

use crate::cultivation_plan::dtos::CultivationPlanCropWithAgrr;
use crate::shared::attr::AttrMap;
use serde_json::Value;

pub trait CultivationPlanOptimizationGateway: Send + Sync {
    fn field_cultivations_present(
        &self,
        plan_id: i64,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>>;

    fn cultivation_plan_crops_with_crop(
        &self,
        plan_id: i64,
    ) -> Result<Vec<CultivationPlanCropWithAgrr>, Box<dyn std::error::Error + Send + Sync>>;

    fn clear_field_cultivations(
        &self,
        plan_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn create_field_cultivation(
        &self,
        plan_id: i64,
        attrs: AttrMap,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;

    fn upsert_cultivation_plan_field(
        &self,
        plan_id: i64,
        name: &str,
        area: f64,
        daily_fixed_cost: f64,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>>;

    fn find_crop_id(
        &self,
        plan_id: i64,
        crop_id: i64,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>>;

    fn apply_optimization_result(
        &self,
        plan_id: i64,
        attrs: AttrMap,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn update_predicted_weather_data(
        &self,
        cultivation_plan_id: i64,
        payload: Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
