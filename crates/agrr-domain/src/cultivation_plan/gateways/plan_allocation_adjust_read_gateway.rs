//! Ruby: `Domain::CultivationPlan::Gateways::PlanAllocationAdjustReadGateway`

use crate::cultivation_plan::dtos::PlanAllocationAdjustReadSnapshot;
use serde_json::Value;
use time::Date;

pub trait PlanAllocationAdjustReadGateway: Send + Sync {
    /// Ruby: `find_adjust_plan_rows_snapshot_by_plan_id` + domain `load_snapshot`.
    /// Rust interactor tests still stub the composite snapshot directly.
    fn find_adjust_read_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<PlanAllocationAdjustReadSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn list_historical_weather_rows(
        &self,
        weather_location_id: Option<i64>,
        historical_start: Date,
        historical_end: Date,
    ) -> Result<Vec<Value>, Box<dyn std::error::Error + Send + Sync>>;

    fn plan_summary_for_adjust_response(
        &self,
        plan_id: i64,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;
}
