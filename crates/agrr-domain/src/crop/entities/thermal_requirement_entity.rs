use rust_decimal::Decimal;

/// Ruby: `Domain::Crop::Entities::ThermalRequirementEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct ThermalRequirementEntity {
    pub id: i64,
    pub crop_stage_id: i64,
    pub required_gdd: Decimal,
}

impl ThermalRequirementEntity {
    pub fn new(id: i64, crop_stage_id: i64, required_gdd: Decimal) -> Result<Self, String> {
        if crop_stage_id == 0 {
            return Err("Crop stage ID is required".into());
        }
        Ok(Self {
            id,
            crop_stage_id,
            required_gdd,
        })
    }
}
