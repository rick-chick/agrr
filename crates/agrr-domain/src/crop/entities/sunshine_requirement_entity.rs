use rust_decimal::Decimal;

/// Ruby: `Domain::Crop::Entities::SunshineRequirementEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct SunshineRequirementEntity {
    pub id: i64,
    pub crop_stage_id: i64,
    pub minimum_sunshine_hours: Option<Decimal>,
    pub target_sunshine_hours: Option<Decimal>,
}

impl SunshineRequirementEntity {
    pub fn new(id: i64, crop_stage_id: i64) -> Result<Self, String> {
        if crop_stage_id == 0 {
            return Err("Crop stage ID is required".into());
        }
        Ok(Self {
            id,
            crop_stage_id,
            minimum_sunshine_hours: None,
            target_sunshine_hours: None,
        })
    }
}
