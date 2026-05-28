use crate::crop::entities::CropStageEntity;

#[derive(Debug, Clone, PartialEq)]
pub struct CropStageOutput {
    pub stage: CropStageEntity,
}

impl CropStageOutput {
    pub fn new(stage: CropStageEntity) -> Self { Self { stage } }
}
