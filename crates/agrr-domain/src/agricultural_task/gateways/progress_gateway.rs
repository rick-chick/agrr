use crate::agricultural_task::gateways::cultivation_plan_gateway::TaskScheduleCrop;

/// Ruby: progress gateway `calculate_progress`
pub trait ProgressGateway: Send + Sync {
    fn calculate_progress(
        &self,
        crop: &TaskScheduleCrop,
        start_date: Option<time::Date>,
        weather_data: &serde_json::Value,
    ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>>;
}
