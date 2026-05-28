use crate::crop::entities::CropStageEntity;

#[derive(Debug, Clone, PartialEq)]
pub struct CropStageListOutput {
    pub stages: Vec<CropStageEntity>,
}
