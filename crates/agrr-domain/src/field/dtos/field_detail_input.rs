/// Ruby: `Domain::Field::Dtos::FieldDetailInput`
#[derive(Debug, Clone, PartialEq)]
pub struct FieldDetailInput {
    pub field_id: i64,
    pub farm_id: Option<i64>,
}

impl FieldDetailInput {
    pub fn new(field_id: i64) -> Self {
        Self {
            field_id,
            farm_id: None,
        }
    }

    pub fn with_farm_id(field_id: i64, farm_id: i64) -> Self {
        Self {
            field_id,
            farm_id: Some(farm_id),
        }
    }
}
