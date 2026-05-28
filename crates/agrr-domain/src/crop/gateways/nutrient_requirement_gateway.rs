use crate::crop::entities::NutrientRequirementEntity;

pub trait NutrientRequirementGateway: Send + Sync {
    fn find_by_crop_stage_id(&self, crop_stage_id: i64) -> Result<Option<NutrientRequirementEntity>, Box<dyn std::error::Error + Send + Sync>>;
}
