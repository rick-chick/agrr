/// Ruby: `Domain::AgriculturalTask::Dtos::AgriculturalTaskCreateInput`
#[derive(Debug, Clone)]
pub struct AgriculturalTaskCreateInput {
    pub name: String,
    pub description: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub weather_dependency: Option<String>,
    pub required_tools: Vec<String>,
    pub skill_level: Option<String>,
    pub region: Option<String>,
    pub task_type: Option<String>,
    pub is_reference: Option<bool>,
}

impl AgriculturalTaskCreateInput {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: Vec::new(),
            skill_level: None,
            region: None,
            task_type: None,
            is_reference: None,
        }
    }
}
