use crate::field::entities::FieldEntity;
use crate::field::results::FarmRecord;

/// Ruby: `Domain::Field::Results::FarmFieldsList`
#[derive(Debug, Clone, PartialEq)]
pub struct FarmFieldsList {
    pub farm: FarmRecord,
    pub fields: Vec<FieldEntity>,
}

impl FarmFieldsList {
    pub fn new(farm: FarmRecord, fields: Vec<FieldEntity>) -> Self {
        Self { farm, fields }
    }
}
