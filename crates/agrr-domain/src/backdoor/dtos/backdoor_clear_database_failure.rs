/// Ruby: `Domain::Backdoor::Dtos::BackdoorClearDatabaseFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BackdoorClearDatabaseFailure {
    pub message: String,
}

impl BackdoorClearDatabaseFailure {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}
