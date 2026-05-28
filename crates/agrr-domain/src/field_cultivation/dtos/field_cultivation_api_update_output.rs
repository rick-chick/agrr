#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldCultivationApiUpdateOutput {
    pub field_cultivation_id: i64,
    pub start_date: String,
    pub completion_date: String,
    pub cultivation_days: Option<i32>,
    pub message: Option<String>,
}

impl FieldCultivationApiUpdateOutput {
    pub fn public_plan_response(&self) -> bool {
        self.message.is_some()
    }
}
