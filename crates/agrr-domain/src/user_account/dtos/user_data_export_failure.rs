#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserDataExportFailure {
    pub message: String,
}

impl UserDataExportFailure {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}
