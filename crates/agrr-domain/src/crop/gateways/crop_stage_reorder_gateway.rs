use crate::crop::entities::CropStageEntity;

/// Narrow port for atomic crop stage order updates within one crop.
pub trait CropStageReorderGateway: Send + Sync {
    fn reorder_crop_stages(
        &self,
        crop_id: i64,
        orders: &[(i64, i64)],
    ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>>;
}
