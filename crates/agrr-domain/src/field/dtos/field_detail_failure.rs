/// Ruby: `Domain::Field::Dtos::FieldDetailFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldDetailFailure {
    pub message: String,
    pub farm_id: Option<i64>,
}

impl FieldDetailFailure {
    pub fn new(message: impl Into<String>, farm_id: Option<i64>) -> Self {
        Self {
            message: message.into(),
            farm_id,
        }
    }
}
