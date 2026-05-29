//! Ruby: `Domain::FieldCultivation::Mappers::FieldCultivationApiSummaryMapper`

use crate::field_cultivation::dtos::{FieldCultivationApiSummary, FieldCultivationApiSummarySnapshot};

pub fn from_snapshot(snapshot: &FieldCultivationApiSummarySnapshot) -> FieldCultivationApiSummary {
    FieldCultivationApiSummary {
        id: snapshot.id,
        field_name: snapshot.field_name.clone(),
        crop_name: snapshot.crop_name.clone(),
        area: snapshot.area,
        start_date: snapshot.start_date,
        completion_date: snapshot.completion_date,
        cultivation_days: snapshot.cultivation_days,
        estimated_cost: snapshot.estimated_cost,
        gdd: snapshot.gdd,
        status: snapshot.status.clone(),
    }
}

#[cfg(test)]
mod mappers_field_cultivation_api_summary_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/mappers_field_cultivation_api_summary_mapper_test.rs"));
}
