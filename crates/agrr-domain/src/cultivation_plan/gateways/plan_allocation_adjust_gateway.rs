//! Ruby: `Domain::CultivationPlan::Gateways::PlanAllocationAdjustGateway`

use crate::cultivation_plan::errors::AdjustExecutionError;
use serde_json::Value;
use time::Date;

pub trait PlanAllocationAdjustGateway: Send + Sync {
    #[allow(clippy::too_many_arguments)]
    fn adjust(
        &self,
        current_allocation: &Value,
        moves: &[Value],
        fields: &[Value],
        crops: &[Value],
        weather_data: &Value,
        planning_start: Date,
        planning_end: Date,
        interaction_rules: Option<&Value>,
        objective: &str,
        max_time: Option<i64>,
        enable_parallel: bool,
    ) -> Result<Value, AdjustExecutionError>;
}
