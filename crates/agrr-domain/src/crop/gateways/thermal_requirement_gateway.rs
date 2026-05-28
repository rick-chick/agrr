use crate::crop::entities::ThermalRequirementEntity;

pub trait ThermalRequirementGateway: Send + Sync {
    fn find_by_crop_stage_id(&self, crop_stage_id: i64) -> Result<Option<ThermalRequirementEntity>, Box<dyn std::error::Error + Send + Sync>>;
}
