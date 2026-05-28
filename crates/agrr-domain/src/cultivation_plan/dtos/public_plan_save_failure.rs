//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveFailure`

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PublicPlanSaveFailure {
    pub kind: String,
    pub message: Option<String>,
}

impl PublicPlanSaveFailure {
    pub const KIND_SAVE_FAILED: &'static str = "save_failed";
    pub const KIND_UNEXPECTED: &'static str = "unexpected";
    pub const KIND_PLAN_NOT_FOUND: &'static str = "plan_not_found";
    pub const KIND_MISSING_PLAN_ID: &'static str = "missing_plan_id";

    pub fn new(kind: impl Into<String>, message: Option<String>) -> Self {
        Self {
            kind: kind.into(),
            message,
        }
    }
}
