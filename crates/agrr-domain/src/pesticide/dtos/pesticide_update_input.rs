/// Ruby: `Domain::Pesticide::Dtos::PesticideUpdateInput`
#[derive(Debug, Clone, Default)]
pub struct PesticideUpdateInput {
    pub pesticide_id: i64,
    pub name: Option<String>,
    pub active_ingredient: Option<String>,
    pub description: Option<String>,
    pub crop_id: Option<i64>,
    pub pest_id: Option<i64>,
    pub region: Option<String>,
    pub is_reference: Option<bool>,
}

impl PesticideUpdateInput {
    pub fn new(pesticide_id: i64) -> Self {
        Self {
            pesticide_id,
            ..Default::default()
        }
    }
}
