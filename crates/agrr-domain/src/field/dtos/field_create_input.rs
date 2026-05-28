/// Ruby: `Domain::Field::Dtos::FieldCreateInput`
#[derive(Debug, Clone, PartialEq)]
pub struct FieldCreateInput {
    pub name: String,
    pub farm_id: i64,
    pub area: Option<f64>,
    pub daily_fixed_cost: Option<f64>,
    pub region: Option<String>,
}

impl FieldCreateInput {
    pub fn new(name: impl Into<String>, farm_id: i64) -> Self {
        Self {
            name: name.into(),
            farm_id,
            area: None,
            daily_fixed_cost: None,
            region: None,
        }
    }
}
