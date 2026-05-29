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
mod tests {
    use super::*;

    #[test]
    fn from_snapshot_maps_counts_to_crop_delete_usage() {
        let snapshot = CropDeleteUsageSnapshot {
            cultivation_plan_crops_count: 2,
            free_crop_plans_count: 3,
            pesticides_count: 1,
        };

        let dto = from_snapshot(&snapshot);

        assert_eq!(dto.cultivation_plan_crops_count, 2);
        assert_eq!(dto.free_crop_plans_count, 3);
        assert_eq!(dto.pesticides_count, 1);
    }
}
