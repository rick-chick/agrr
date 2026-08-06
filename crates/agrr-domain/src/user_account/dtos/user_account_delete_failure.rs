#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserAccountDeleteFailure {
    pub message: String,
}

impl UserAccountDeleteFailure {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}
