//! Ruby: `Domain::CultivationPlan::Gateways::PlanAllocationAllocateGateway`

use serde_json::Value;
use time::Date;

pub trait PlanAllocationAllocateGateway: Send + Sync {
    #[allow(clippy::too_many_arguments)]
    fn allocate(
        &self,
        fields: &[Value],
        crops: &[Value],
        weather_data: &Value,
        planning_start: Date,
        planning_end: Date,
        interaction_rules: Option<&Value>,
        objective: &str,
        max_time: Option<i64>,
        enable_parallel: bool,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;
}
