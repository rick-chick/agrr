/// Ruby: `Domain::Pesticide::Dtos::PesticideCreateInput`
#[derive(Debug, Clone)]
pub struct PesticideCreateInput {
    pub name: String,
    pub active_ingredient: Option<String>,
    pub description: Option<String>,
    pub crop_id: Option<i64>,
    pub pest_id: Option<i64>,
    pub region: Option<String>,
    pub is_reference: Option<bool>,
}

impl PesticideCreateInput {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            active_ingredient: None,
            description: None,
            crop_id: None,
            pest_id: None,
            region: None,
            is_reference: None,
        }
    }
}
