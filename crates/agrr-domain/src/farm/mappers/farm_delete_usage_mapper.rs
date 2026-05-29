//! Ruby: `Domain::Farm::Mappers::FarmDeleteUsageMapper`

use crate::farm::dtos::FarmDeleteUsage;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FarmDeleteUsageWire {
    pub free_crop_plans_count: i32,
}

pub fn from_wire(wire: &FarmDeleteUsageWire) -> FarmDeleteUsage {
    FarmDeleteUsage::new(wire.free_crop_plans_count)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn from_wire_maps_free_crop_plans_count() {
        let wire = FarmDeleteUsageWire {
            free_crop_plans_count: 4,
        };

        let dto = from_wire(&wire);

        assert_eq!(dto.free_crop_plans_count, 4);
    }
}
