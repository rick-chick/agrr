#[derive(Debug, Clone, PartialEq)]
pub struct MastersCropTaskTemplateCreateInput {
    pub user_id: i64,
    pub crop_id: i64,
    pub agricultural_task_id: Option<i64>,
    pub name: Option<String>,
    pub description: Option<String>,
    pub time_per_sqm: Option<rust_decimal::Decimal>,
    pub weather_dependency: Option<String>,
    pub required_tools: Option<Vec<String>>,
    pub skill_level: Option<String>,
}

impl MastersCropTaskTemplateCreateInput {
    pub fn new(user_id: i64, crop_id: i64, agricultural_task_id: Option<i64>) -> Self {
        Self {
            user_id,
            crop_id,
            agricultural_task_id,
            name: None,
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: None,
            skill_level: None,
        }
    }
}
