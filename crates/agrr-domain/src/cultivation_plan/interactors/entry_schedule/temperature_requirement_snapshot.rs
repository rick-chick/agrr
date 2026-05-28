//! Ruby: `Domain::CultivationPlan::Interactors::EntrySchedule::TemperatureRequirementSnapshot`

#[derive(Debug, Clone, PartialEq)]
pub struct TemperatureRequirementSnapshot {
    pub frost_threshold: Option<f64>,
    pub optimal_min: Option<f64>,
    pub optimal_max: Option<f64>,
    pub base_temperature: Option<f64>,
}
