//! Ruby: `Domain::Crop::Mappers::CropDeleteUsageMapper`

use crate::crop::dtos::CropDeleteUsage;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CropDeleteUsageWire {
    pub cultivation_plan_crops_count: i32,
    pub free_crop_plans_count: i32,
    pub pesticides_count: i32,
}

pub fn from_wire(wire: &CropDeleteUsageWire) -> CropDeleteUsage {
    CropDeleteUsage::new(
        wire.cultivation_plan_crops_count,
        wire.free_crop_plans_count,
        wire.pesticides_count,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn from_wire_maps_counts_to_crop_delete_usage() {
        let wire = CropDeleteUsageWire {
            cultivation_plan_crops_count: 2,
            free_crop_plans_count: 3,
            pesticides_count: 1,
        };

        let dto = from_wire(&wire);

        assert_eq!(dto.cultivation_plan_crops_count, 2);
        assert_eq!(dto.free_crop_plans_count, 3);
        assert_eq!(dto.pesticides_count, 1);
    }
}
