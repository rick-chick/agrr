use crate::public_plan::mappers::entry_schedule_crop_mapper::CropStageRow;

/// Crop gateway for entry schedule show (Ruby: crop_gateway).
pub trait EntryScheduleCropGateway: Send + Sync {
    fn list_by_crop_id(&self, crop_id: i64) -> Vec<CropStageRow>;
}
