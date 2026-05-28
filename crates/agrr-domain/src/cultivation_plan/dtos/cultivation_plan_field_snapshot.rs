//! Ruby: `Domain::CultivationPlan::Dtos::CultivationPlanFieldSnapshot`

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanFieldSnapshot {
    pub id: i64,
    pub name: String,
    pub area: f64,
    pub cultivation_count: i32,
}

impl CultivationPlanFieldSnapshot {
    pub fn new(id: i64, name: impl Into<String>, area: f64) -> Self {
        Self {
            id,
            name: name.into(),
            area,
            cultivation_count: 0,
        }
    }
}
