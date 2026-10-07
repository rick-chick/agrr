//! Ruby: `Domain::CultivationPlan::Interactors::EntrySchedule::CropStageSnapshot`

#[derive(Debug, Clone, PartialEq)]
pub struct CropStageSnapshot {
    pub id: i64,
    pub name: String,
    pub order: i32,
}
