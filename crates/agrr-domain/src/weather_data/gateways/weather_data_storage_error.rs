//! Bulk weather storage failures (distinct from empty data).

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WeatherDataStorageError {
    message: String,
}

impl WeatherDataStorageError {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }

    pub fn message(&self) -> &str {
        &self.message
    }
}

impl std::fmt::Display for WeatherDataStorageError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

impl std::error::Error for WeatherDataStorageError {}
