#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropCreateLimitExceededFailure {
    pub message: String,
}

impl CropCreateLimitExceededFailure {
    pub fn new(message: impl Into<String>) -> Self {
        Self { message: message.into() }
    }
}
