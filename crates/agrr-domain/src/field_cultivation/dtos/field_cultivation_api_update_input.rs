#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldCultivationApiUpdateInput {
    pub field_cultivation_id: i64,
    pub start_date: String,
    pub completion_date: String,
    pub public_plan: bool,
}

impl FieldCultivationApiUpdateInput {
    pub fn new(
        field_cultivation_id: i64,
        start_date: impl Into<String>,
        completion_date: impl Into<String>,
        public_plan: bool,
    ) -> Self {
        Self {
            field_cultivation_id,
            start_date: start_date.into(),
            completion_date: completion_date.into(),
            public_plan,
        }
    }

    pub fn public_plan(&self) -> bool {
        self.public_plan
    }
}
