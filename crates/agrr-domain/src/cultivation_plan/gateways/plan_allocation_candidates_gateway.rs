//! Ruby: `Domain::CultivationPlan::Gateways::PlanAllocationCandidatesGateway`

use serde_json::Value;
use time::Date;

pub trait PlanAllocationCandidatesGateway: Send + Sync {
    #[allow(clippy::too_many_arguments)]
    fn candidates(
        &self,
        current_allocation: &Value,
        fields: &[Value],
        crops: &[Value],
        target_crop: &Value,
        weather_data: &Value,
        planning_start: Date,
        planning_end: Date,
        interaction_rules: Option<&Value>,
    ) -> Result<Vec<Value>, Box<dyn std::error::Error + Send + Sync>>;
}
