//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveFromSessionOutput`

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PublicPlanSaveFromSessionOutput {
    pub success: bool,
    pub error_message: Option<String>,
}

impl PublicPlanSaveFromSessionOutput {
    pub fn success() -> Self {
        Self {
            success: true,
            error_message: None,
        }
    }

    pub fn failure(message: impl Into<String>) -> Self {
        Self {
            success: false,
            error_message: Some(message.into()),
        }
    }
}
