//! Ruby: `Domain::Crop::Mappers::CropDeleteUsageMapper`

use crate::crop::dtos::{CropDeleteUsage, CropDeleteUsageSnapshot};

pub fn from_snapshot(snapshot: &CropDeleteUsageSnapshot) -> CropDeleteUsage {
    CropDeleteUsage::new(
        snapshot.cultivation_plan_crops_count,
        snapshot.free_crop_plans_count,
        snapshot.pesticides_count,
    )
}

#[cfg(test)]
mod mappers_crop_delete_usage_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/mappers_crop_delete_usage_mapper_test.rs"));
}
