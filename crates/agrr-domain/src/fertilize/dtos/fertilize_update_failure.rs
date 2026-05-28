/// Ruby: `Domain::Fertilize::Dtos::FertilizeUpdateFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FertilizeUpdateFailure {
    pub message: String,
    pub fertilize_id: Option<i64>,
}

impl FertilizeUpdateFailure {
    pub fn new(message: impl Into<String>, fertilize_id: Option<i64>) -> Self {
        Self {
            message: message.into(),
            fertilize_id,
        }
    }
}
