//! Ruby: `Domain::Pest::Mappers::PestDeleteUsageMapper`

use crate::pest::dtos::{PestDeleteUsage, PestDeleteUsageSnapshot};

pub fn from_snapshot(snapshot: &PestDeleteUsageSnapshot) -> PestDeleteUsage {
    PestDeleteUsage::new(snapshot.pesticides_count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn from_snapshot_maps_pesticides_count() {
        let snapshot = PestDeleteUsageSnapshot {
            pesticides_count: 5,
        };

        let dto = from_snapshot(&snapshot);

        assert_eq!(dto.pesticides_count, 5);
    }
}
