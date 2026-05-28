use crate::crop::entities::TemperatureRequirementEntity;

pub trait TemperatureRequirementGateway: Send + Sync {
    fn find_by_crop_stage_id(&self, crop_stage_id: i64) -> Result<Option<TemperatureRequirementEntity>, Box<dyn std::error::Error + Send + Sync>>;
}
