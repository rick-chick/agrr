//! Ruby: `Domain::CultivationPlan::Dtos::AddCropAdjustResult`

#[derive(Debug, Clone, PartialEq)]
pub struct AddCropAdjustResult {
    pub success: bool,
    pub message: Option<String>,
    pub http_status: Option<i32>,
}

impl AddCropAdjustResult {
    pub fn success() -> Self {
        Self {
            success: true,
            message: None,
            http_status: None,
        }
    }

    pub fn failure(message: impl Into<String>, http_status: Option<i32>) -> Self {
        Self {
            success: false,
            message: Some(message.into()),
            http_status,
        }
    }

    pub fn is_success(&self) -> bool {
        self.success
    }
}
