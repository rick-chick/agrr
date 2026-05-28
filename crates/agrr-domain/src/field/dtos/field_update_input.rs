/// Ruby: `Domain::Field::Dtos::FieldUpdateInput`
#[derive(Debug, Clone, PartialEq)]
pub struct FieldUpdateInput {
    pub id: i64,
    pub name: Option<String>,
    pub area: Option<f64>,
    pub daily_fixed_cost: Option<f64>,
    pub region: Option<String>,
}

impl FieldUpdateInput {
    pub fn new(id: i64) -> Self {
        Self {
            id,
            name: None,
            area: None,
            daily_fixed_cost: None,
            region: None,
        }
    }
}
