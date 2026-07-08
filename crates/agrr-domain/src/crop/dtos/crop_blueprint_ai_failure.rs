use crate::crop::dtos::HttpStatus;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropBlueprintAiFailure {
    pub http_status: HttpStatus,
    pub message: String,
}

impl CropBlueprintAiFailure {
    pub fn new(http_status: HttpStatus, message: impl Into<String>) -> Self {
        Self {
            http_status,
            message: message.into(),
        }
    }
}
