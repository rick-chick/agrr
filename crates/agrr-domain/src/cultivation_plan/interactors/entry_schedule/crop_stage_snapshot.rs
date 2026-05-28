//! Ruby: `Domain::CultivationPlan::Interactors::EntrySchedule::CropStageSnapshot`

use super::temperature_requirement_snapshot::TemperatureRequirementSnapshot;

#[derive(Debug, Clone, PartialEq)]
pub struct CropStageSnapshot {
    pub id: i64,
    pub name: String,
    pub order: i32,
    pub temperature_requirement: Option<TemperatureRequirementSnapshot>,
}
