use crate::shared::attr::AttrMap;

/// Ruby: `Domain::Pest::Dtos::PestCreateInput`
#[derive(Debug, Clone)]
pub struct PestCreateInput {
    pub name: String,
    pub name_scientific: Option<String>,
    pub family: Option<String>,
    pub order: Option<String>,
    pub description: Option<String>,
    pub occurrence_season: Option<String>,
    pub region: Option<String>,
    pub is_reference: Option<bool>,
    pub pest_temperature_profile_attributes: Option<AttrMap>,
    pub pest_thermal_requirement_attributes: Option<AttrMap>,
    pub pest_control_methods_attributes: Option<Vec<AttrMap>>,
    pub crop_ids: Vec<i64>,
}

impl PestCreateInput {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            name_scientific: None,
            family: None,
            order: None,
            description: None,
            occurrence_season: None,
            region: None,
            is_reference: None,
            pest_temperature_profile_attributes: None,
            pest_thermal_requirement_attributes: None,
            pest_control_methods_attributes: None,
            crop_ids: vec![],
        }
    }
}
