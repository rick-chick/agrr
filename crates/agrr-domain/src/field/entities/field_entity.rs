/// Ruby: `Domain::Field::Entities::FieldEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct FieldEntity {
    pub id: i64,
    pub farm_id: i64,
    pub user_id: Option<i64>,
    pub name: String,
    pub description: Option<String>,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
    pub area: Option<f64>,
    pub daily_fixed_cost: Option<f64>,
    pub region: Option<String>,
}

impl FieldEntity {
    pub fn display_name(&self) -> String {
        if self.name.trim().is_empty() {
            format!("Field {}", self.id)
        } else {
            self.name.clone()
        }
    }
}
