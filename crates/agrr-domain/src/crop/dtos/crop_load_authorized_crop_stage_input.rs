#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CropLoadAuthorizedCropStageInput {
    pub crop_id: i64,
    pub crop_stage_id: i64,
    pub for_edit: bool,
}

impl CropLoadAuthorizedCropStageInput {
    pub fn new(crop_id: i64, crop_stage_id: i64, for_edit: bool) -> Self {
        Self { crop_id, crop_stage_id, for_edit }
    }
}
