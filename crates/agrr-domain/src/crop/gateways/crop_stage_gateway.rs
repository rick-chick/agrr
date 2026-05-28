use crate::crop::entities::CropStageEntity;

/// Ruby: `Domain::Crop::Gateways::CropStageGateway`
pub trait CropStageGateway: Send + Sync {
    fn find_by_id(&self, crop_stage_id: i64) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>>;
}
