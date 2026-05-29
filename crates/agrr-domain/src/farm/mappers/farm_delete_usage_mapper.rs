//! Ruby: `Domain::Farm::Mappers::FarmDeleteUsageMapper`

use crate::farm::dtos::{FarmDeleteUsage, FarmDeleteUsageSnapshot};

pub fn from_snapshot(snapshot: &FarmDeleteUsageSnapshot) -> FarmDeleteUsage {
    FarmDeleteUsage::new(snapshot.free_crop_plans_count)
}

#[cfg(test)]
mod mappers_farm_delete_usage_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/mappers_farm_delete_usage_mapper_test.rs"));
}
