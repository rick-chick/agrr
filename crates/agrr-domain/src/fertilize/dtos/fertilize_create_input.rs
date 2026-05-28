/// Ruby: `Domain::Fertilize::Dtos::FertilizeCreateInput`
#[derive(Debug, Clone)]
pub struct FertilizeCreateInput {
    pub name: String,
    pub n: Option<f64>,
    pub p: Option<f64>,
    pub k: Option<f64>,
    pub description: Option<String>,
    pub package_size: Option<f64>,
    pub region: Option<String>,
    pub is_reference: Option<bool>,
}

impl FertilizeCreateInput {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            n: None,
            p: None,
            k: None,
            description: None,
            package_size: None,
            region: None,
            is_reference: None,
        }
    }
}
