use crate::fertilize::dtos::HttpStatus;

/// Ruby: `Domain::Fertilize::Dtos::FertilizeAiCreateFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FertilizeAiCreateFailure {
    pub http_status: HttpStatus,
    pub message: String,
}

impl FertilizeAiCreateFailure {
    pub fn new(http_status: HttpStatus, message: impl Into<String>) -> Self {
        Self {
            http_status,
            message: message.into(),
        }
    }
}
