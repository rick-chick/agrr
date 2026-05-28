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

#[cfg(test)]
mod tests {
    use super::*;

    // Ruby: test "raises when name is blank"
    #[test]
    fn raises_when_name_is_blank() {
        assert!(CropStageEntity::new(1, 1, "  ", 0).is_err());
    }

    // Ruby: test "raises when crop_id is nil"
    #[test]
    fn raises_when_crop_id_is_nil() {
        assert!(CropStageEntity::new(1, 0, "Stage", 0).is_err());
    }

    // Ruby: test "raises when order is nil"
    #[test]
    fn raises_when_order_is_nil() {
        // Rust uses i32; nil order represented as missing — use Option in builder if needed.
        // Ruby rejects nil order; we validate via dedicated constructor accepting Option.
        assert!(CropStageEntity::try_new_optional_order(1, 1, "Stage", None).is_err());
    }

    // Ruby: test "creates entity with valid attributes"
    #[test]
    fn creates_entity_with_valid_attributes() {
        let entity = CropStageEntity::new(1, 10, "Vegetative", 1).unwrap();
        assert_eq!(entity.name, "Vegetative");
        assert_eq!(entity.crop_id, 10);
        assert_eq!(entity.order, 1);
    }

    // Ruby: test "stores nested requirements when provided"
    #[test]
    fn stores_nested_requirements_when_provided() {
        let mut entity = CropStageEntity::new(1, 10, "Stage", 0).unwrap();
        entity.thermal_requirement = Some(
            ThermalRequirementEntity::new(1, 10, rust_decimal::Decimal::from(200)).unwrap(),
        );
        assert!(entity.thermal_requirement.is_some());
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
