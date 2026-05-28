//! Ruby: `Domain::CultivationPlan::Dtos::CultivationPlanDestroyOutput`

use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct CultivationPlanDestroyOutput {
    pub undo: Value,
}

impl CultivationPlanDestroyOutput {
    pub fn new(undo: Value) -> Self {
        Self { undo }
    }
}
