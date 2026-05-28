//! Ruby: `Domain::CultivationPlan::Dtos::PrivatePlanInitializeFromSelectionFailure`

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PrivatePlanInitializeFromSelectionFailure {
    pub http_status: &'static str,
    pub message: String,
}

impl PrivatePlanInitializeFromSelectionFailure {
    pub const HTTP_NOT_FOUND: &'static str = "not_found";
    pub const HTTP_UNPROCESSABLE_ENTITY: &'static str = "unprocessable_entity";

    pub fn new(http_status: &'static str, message: impl Into<String>) -> Self {
        Self {
            http_status,
            message: message.into(),
        }
    }
}
