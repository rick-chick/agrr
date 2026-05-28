use crate::crop::entities::CropEntity;

#[derive(Debug, Clone, PartialEq)]
pub struct CropAiCreateOutput {
    pub crop: CropEntity,
}
