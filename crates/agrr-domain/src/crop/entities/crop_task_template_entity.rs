use rust_decimal::Decimal;

/// Ruby: `Domain::Crop::Entities::CropTaskTemplateEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct CropTaskTemplateEntity {
    pub id: i64,
    pub crop_id: i64,
    pub agricultural_task_id: i64,
    pub name: String,
    pub description: Option<String>,
    pub time_per_sqm: Option<Decimal>,
    pub weather_dependency: Option<String>,
    pub required_tools: Vec<String>,
    pub skill_level: Option<String>,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}
