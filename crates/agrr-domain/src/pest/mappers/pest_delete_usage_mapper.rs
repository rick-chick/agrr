//! Ruby: `Domain::Pest::Mappers::PestDeleteUsageMapper`

use crate::pest::dtos::{PestDeleteUsage, PestDeleteUsageSnapshot};

pub fn from_snapshot(snapshot: &PestDeleteUsageSnapshot) -> PestDeleteUsage {
    PestDeleteUsage::new(snapshot.pesticides_count)
}

#[cfg(test)]
mod mappers_pest_delete_usage_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/mappers_pest_delete_usage_mapper_test.rs"));
}
