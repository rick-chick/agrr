use crate::pest::entities::PestEntity;

/// Gateway detail bundle before enrichment (Ruby gateway `find_pest_show_detail`).
#[derive(Debug, Clone)]
pub struct PestShowDetail {
    pub pest: PestEntity,
    pub temperature_profile: Option<serde_json::Value>,
    pub thermal_requirement: Option<serde_json::Value>,
    pub control_methods: Vec<serde_json::Value>,
    pub associated_crops: Vec<serde_json::Value>,
}

/// Ruby: `Domain::Pest::Dtos::PestDetailOutput`
#[derive(Debug, Clone)]
pub struct PestDetailOutput {
    pub pest: PestEntity,
    pub temperature_profile: Option<serde_json::Value>,
    pub thermal_requirement: Option<serde_json::Value>,
    pub control_methods: Vec<serde_json::Value>,
    pub associated_crops: Vec<serde_json::Value>,
}

impl PestDetailOutput {
    pub fn from_show_detail(detail: PestShowDetail) -> Self {
        Self {
            pest: detail.pest,
            temperature_profile: detail.temperature_profile,
            thermal_requirement: detail.thermal_requirement,
            control_methods: detail.control_methods,
            associated_crops: detail.associated_crops,
        }
    }
}
