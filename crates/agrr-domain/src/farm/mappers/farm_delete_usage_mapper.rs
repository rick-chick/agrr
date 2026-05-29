//! Ruby: `Domain::Farm::Mappers::FarmDeleteUsageMapper`

use crate::farm::dtos::{FarmDeleteUsage, FarmDeleteUsageSnapshot};

pub fn from_snapshot(snapshot: &FarmDeleteUsageSnapshot) -> FarmDeleteUsage {
    FarmDeleteUsage::new(snapshot.free_crop_plans_count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn from_snapshot_maps_free_crop_plans_count() {
        let snapshot = FarmDeleteUsageSnapshot {
            free_crop_plans_count: 4,
        };

        let dto = from_snapshot(&snapshot);

        assert_eq!(dto.free_crop_plans_count, 4);
    }
}
