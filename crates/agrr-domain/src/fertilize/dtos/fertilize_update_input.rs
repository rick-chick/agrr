/// Ruby: `Domain::Fertilize::Dtos::FertilizeUpdateInput`
#[derive(Debug, Clone, Default)]
pub struct FertilizeUpdateInput {
    pub fertilize_id: i64,
    pub name: Option<String>,
    pub n: Option<f64>,
    pub p: Option<f64>,
    pub k: Option<f64>,
    pub description: Option<String>,
    pub package_size: Option<f64>,
    pub region: Option<String>,
    pub is_reference: Option<bool>,
}

impl FertilizeUpdateInput {
    pub fn new(fertilize_id: i64) -> Self {
        Self {
            fertilize_id,
            ..Default::default()
        }
    }
}
