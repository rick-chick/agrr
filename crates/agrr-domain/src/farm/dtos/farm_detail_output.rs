use crate::farm::entities::{FarmEntity, FieldEntity};

/// Ruby: `Domain::Farm::Dtos::FarmDetailOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct FarmDetailOutput {
    pub farm: FarmEntity,
    pub fields: Vec<FieldEntity>,
    pub turbo_stream_subscription: Option<String>,
}

impl FarmDetailOutput {
    pub fn new(farm: FarmEntity, fields: Vec<FieldEntity>) -> Self {
        Self {
            farm,
            fields,
            turbo_stream_subscription: None,
        }
    }
}
