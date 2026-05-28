use crate::pest::dtos::HttpStatus;

/// Ruby: `Domain::Pest::Dtos::PestAiCreateFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PestAiCreateFailure {
    pub http_status: HttpStatus,
    pub message: String,
}

impl PestAiCreateFailure {
    pub fn new(http_status: HttpStatus, message: impl Into<String>) -> Self {
        Self {
            http_status,
            message: message.into(),
        }
    }
}
