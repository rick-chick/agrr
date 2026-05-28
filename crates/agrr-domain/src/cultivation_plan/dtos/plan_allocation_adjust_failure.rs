//! Ruby: `Domain::CultivationPlan::Dtos::PlanAllocationAdjustFailure`

#[derive(Debug, Clone, PartialEq)]
pub struct PlanAllocationAdjustFailure {
    pub kind: String,
    pub message: String,
}

impl PlanAllocationAdjustFailure {
    pub const KIND_NO_WEATHER_LOCATION: &'static str = "no_weather_location";
    pub const KIND_INVALID_DATE: &'static str = "invalid_date";
    pub const KIND_CALCULATE_PERIOD_FAILED: &'static str = "calculate_period_failed";
    pub const KIND_WEATHER_FETCH_FAILED: &'static str = "weather_fetch_failed";
    pub const KIND_ADJUST_EXECUTION_FAILED: &'static str = "adjust_execution_failed";
    pub const KIND_RESULT_EMPTY: &'static str = "result_empty";
    pub const KIND_CROP_MISSING_GROWTH_STAGES: &'static str = "crop_missing_growth_stages";
    pub const KIND_NOT_FOUND: &'static str = "not_found";
    pub const KIND_UNEXPECTED: &'static str = "unexpected";
}
