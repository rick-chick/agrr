/// Ruby: `Domain::Farm::Dtos::FarmCreateLimitExceededFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FarmCreateLimitExceededFailure {
    pub message: String,
}

impl FarmCreateLimitExceededFailure {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}
