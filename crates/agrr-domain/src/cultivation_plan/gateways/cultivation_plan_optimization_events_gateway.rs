//! Ruby: `Domain::CultivationPlan::Gateways::CultivationPlanOptimizationEventsGateway`

use crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot;

pub trait CultivationPlanOptimizationEventsGateway: Send + Sync {
    fn broadcast_field_added(
        &self,
        plan_id: i64,
        plan_type: &str,
        field_snapshot: &CultivationPlanFieldSnapshot,
        total_area: f64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn broadcast_field_removed(
        &self,
        plan_id: i64,
        plan_type: &str,
        field_id: i64,
        total_area: f64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn broadcast_optimization_complete(
        &self,
        plan_id: i64,
        status: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
