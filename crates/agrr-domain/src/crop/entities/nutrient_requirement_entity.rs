use rust_decimal::Decimal;

/// Ruby: `Domain::Crop::Entities::NutrientRequirementEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct NutrientRequirementEntity {
    pub id: i64,
    pub crop_stage_id: i64,
    pub daily_uptake_n: Option<Decimal>,
    pub daily_uptake_p: Option<Decimal>,
    pub daily_uptake_k: Option<Decimal>,
    pub region: Option<String>,
}

impl NutrientRequirementEntity {
    pub fn new(id: i64, crop_stage_id: i64) -> Result<Self, String> {
        if crop_stage_id == 0 {
            return Err("Crop stage ID is required".into());
        }
        Ok(Self {
            id,
            crop_stage_id,
            daily_uptake_n: None,
            daily_uptake_p: None,
            daily_uptake_k: None,
            region: None,
        })
    }
}
