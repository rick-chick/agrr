use crate::crop::entities::SunshineRequirementEntity;

pub trait SunshineRequirementGateway: Send + Sync {
    fn find_by_crop_stage_id(&self, crop_stage_id: i64) -> Result<Option<SunshineRequirementEntity>, Box<dyn std::error::Error + Send + Sync>>;
}
