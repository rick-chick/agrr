/// Ruby: `Domain::Farm::Entities::FieldEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct FieldEntity {
    pub id: i64,
    pub name: String,
    pub area: Option<f64>,
    pub daily_fixed_cost: Option<f64>,
    pub region: Option<String>,
    pub farm_id: i64,
    pub user_id: Option<i64>,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
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

#[cfg(test)]
mod entities_field_entity_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/entities_field_entity_test.rs"));
}
