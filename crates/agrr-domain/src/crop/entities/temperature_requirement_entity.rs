use rust_decimal::Decimal;

/// Ruby: `Domain::Crop::Entities::TemperatureRequirementEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct TemperatureRequirementEntity {
    pub id: i64,
    pub crop_stage_id: i64,
    pub base_temperature: Option<Decimal>,
    pub optimal_min: Option<Decimal>,
    pub optimal_max: Option<Decimal>,
    pub low_stress_threshold: Option<Decimal>,
    pub high_stress_threshold: Option<Decimal>,
    pub frost_threshold: Option<Decimal>,
    pub sterility_risk_threshold: Option<Decimal>,
    pub max_temperature: Option<Decimal>,
}

impl TemperatureRequirementEntity {
    pub fn new(id: i64, crop_stage_id: i64) -> Result<Self, String> {
        if crop_stage_id == 0 {
            return Err("Crop stage ID is required".into());
        }
        Ok(Self {
            id,
            crop_stage_id,
            base_temperature: None,
            optimal_min: None,
            optimal_max: None,
            low_stress_threshold: None,
            high_stress_threshold: None,
            frost_threshold: None,
            sterility_risk_threshold: None,
            max_temperature: None,
        })
    }
}
