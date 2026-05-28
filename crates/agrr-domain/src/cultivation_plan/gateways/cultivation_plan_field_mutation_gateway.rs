//! Ruby: `Domain::CultivationPlan::Gateways::CultivationPlanFieldMutationGateway`

use crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot;

pub trait CultivationPlanFieldMutationGateway: Send + Sync {
    fn count_fields(
        &self,
        plan_id: i64,
    ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>>;

    fn find_field(
        &self,
        plan_id: i64,
        field_id: i64,
    ) -> Result<Option<CultivationPlanFieldSnapshot>, Box<dyn std::error::Error + Send + Sync>>;

    fn create_field(
        &self,
        plan_id: i64,
        field_name: &str,
        field_area: f64,
        daily_fixed_cost: Option<f64>,
    ) -> Result<CultivationPlanFieldSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn delete_field(
        &self,
        plan_id: i64,
        field_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn refresh_total_area(
        &self,
        plan_id: i64,
    ) -> Result<f64, Box<dyn std::error::Error + Send + Sync>>;
}
