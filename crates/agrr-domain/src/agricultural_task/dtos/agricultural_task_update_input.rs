/// Ruby: `Domain::AgriculturalTask::Dtos::AgriculturalTaskUpdateInput`
#[derive(Debug, Clone, Default)]
pub struct AgriculturalTaskUpdateInput {
    pub id: i64,
    pub name: Option<String>,
    pub description: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub weather_dependency: Option<String>,
    pub required_tools: Option<Vec<String>>,
    pub skill_level: Option<String>,
    pub region: Option<String>,
    pub task_type: Option<String>,
    pub is_reference: Option<bool>,
    pub selected_crop_ids: Option<Vec<i64>>,
}
