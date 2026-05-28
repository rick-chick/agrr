//! Ruby: `Domain::CultivationPlan::Gateways::EntryScheduleOptimizationGateway`

use serde_json::Value;

pub trait EntryScheduleOptimizationGateway: Send + Sync {
    #[allow(clippy::too_many_arguments)]
    fn optimize_period(
        &self,
        crop_name: &str,
        crop_variety: Option<&str>,
        weather_data: &Value,
        evaluation_start: time::Date,
        evaluation_end: time::Date,
        crop_requirement: &Value,
        crop: &serde_json::Value,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;
}
