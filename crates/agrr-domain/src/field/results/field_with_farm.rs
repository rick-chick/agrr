use crate::field::entities::FieldEntity;
use crate::field::results::FarmRecord;

/// Ruby: `Domain::Field::Results::FieldWithFarm`
#[derive(Debug, Clone, PartialEq)]
pub struct FieldWithFarm {
    pub farm: FarmRecord,
    pub field: FieldEntity,
}

impl FieldWithFarm {
    pub fn new(farm: FarmRecord, field: FieldEntity) -> Self {
        Self { farm, field }
    }
}
