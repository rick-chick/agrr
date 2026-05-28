use crate::crop::entities::{CropEntity, CropStageEntity};

#[derive(Debug, Clone, PartialEq)]
pub struct AuthorizedCropStageInCropContext {
    pub crop_entity: CropEntity,
    pub crop_stage_entity: CropStageEntity,
}

impl AuthorizedCropStageInCropContext {
    pub fn new(crop_entity: CropEntity, crop_stage_entity: CropStageEntity) -> Self {
        Self { crop_entity, crop_stage_entity }
    }
}
