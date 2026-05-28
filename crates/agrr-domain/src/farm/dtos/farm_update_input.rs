/// Ruby: `Domain::Farm::Dtos::FarmUpdateInput`
#[derive(Debug, Clone, PartialEq)]
pub struct FarmUpdateInput {
    pub farm_id: i64,
    pub name: Option<String>,
    pub region: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
}

impl FarmUpdateInput {
    pub fn new(farm_id: i64, name: Option<String>) -> Self {
        Self {
            farm_id,
            name,
            region: None,
            latitude: None,
            longitude: None,
        }
    }
}
