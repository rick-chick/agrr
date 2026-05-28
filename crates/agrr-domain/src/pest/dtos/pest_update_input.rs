use crate::shared::attr::AttrMap;

/// Ruby: `Domain::Pest::Dtos::PestUpdateInput`
#[derive(Debug, Clone)]
pub struct PestUpdateInput {
    pub pest_id: i64,
    pub name: Option<String>,
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
    pub crop_ids: Option<Vec<i64>>,
}
