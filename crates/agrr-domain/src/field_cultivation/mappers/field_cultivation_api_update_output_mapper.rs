//! Ruby: `Domain::FieldCultivation::Mappers::FieldCultivationApiUpdateOutputMapper`

use crate::field_cultivation::dtos::{
    FieldCultivationApiUpdateOutput, FieldCultivationApiUpdateOutputSnapshot,
};

pub fn from_snapshot(
    snapshot: &FieldCultivationApiUpdateOutputSnapshot,
) -> FieldCultivationApiUpdateOutput {
    FieldCultivationApiUpdateOutput {
        field_cultivation_id: snapshot.field_cultivation_id,
        start_date: snapshot.start_date.clone(),
        completion_date: snapshot.completion_date.clone(),
        cultivation_days: snapshot.cultivation_days,
        message: None,
    }
}

#[cfg(test)]
mod mappers_field_cultivation_api_update_output_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/mappers_field_cultivation_api_update_output_mapper_test.rs"));
}
