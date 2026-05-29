use crate::crop::entities::{
    nutrient_requirement_entity::NutrientRequirementEntity,
    sunshine_requirement_entity::SunshineRequirementEntity,
    temperature_requirement_entity::TemperatureRequirementEntity,
    thermal_requirement_entity::ThermalRequirementEntity,
};

/// Ruby: `Domain::Crop::Entities::CropStageEntity`
#[derive(Debug, Clone, PartialEq)]
pub struct CropStageEntity {
    pub id: i64,
    pub crop_id: i64,
    pub name: String,
    pub order: i32,
    pub temperature_requirement: Option<TemperatureRequirementEntity>,
    pub thermal_requirement: Option<ThermalRequirementEntity>,
    pub sunshine_requirement: Option<SunshineRequirementEntity>,
    pub nutrient_requirement: Option<NutrientRequirementEntity>,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl CropStageEntity {
    pub fn new(id: i64, crop_id: i64, name: impl Into<String>, order: i32) -> Result<Self, String> {
        let name = name.into();
        if name.trim().is_empty() {
            return Err("Name is required".into());
        }
        if crop_id == 0 {
            return Err("Crop ID is required".into());
        }
        Ok(Self {
            id,
            crop_id,
            name,
            order,
            temperature_requirement: None,
            thermal_requirement: None,
            sunshine_requirement: None,
            nutrient_requirement: None,
            created_at: None,
            updated_at: None,
        })
    }
}

impl CropStageEntity {
    pub fn try_new_optional_order(
        id: i64,
        crop_id: i64,
        name: impl Into<String>,
        order: Option<i32>,
    ) -> Result<Self, String> {
        let order = order.ok_or_else(|| "Order is required".to_string())?;
        Self::new(id, crop_id, name, order)
    }
}

#[cfg(test)]
mod entities_crop_stage_entity_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/entities_crop_stage_entity_test.rs"));
}
