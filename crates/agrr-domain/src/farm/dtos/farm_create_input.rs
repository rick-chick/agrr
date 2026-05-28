/// Ruby: `Domain::Farm::Dtos::FarmCreateInput`
#[derive(Debug, Clone, PartialEq)]
pub struct FarmCreateInput {
    pub name: String,
    pub region: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
}

impl FarmCreateInput {
    pub fn new(
        name: impl Into<String>,
        region: Option<String>,
        latitude: Option<f64>,
        longitude: Option<f64>,
    ) -> Self {
        Self {
            name: name.into(),
            region,
            latitude,
            longitude,
        }
    }
}
