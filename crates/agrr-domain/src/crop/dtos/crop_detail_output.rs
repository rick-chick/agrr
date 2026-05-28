use crate::crop::entities::CropEntity;

#[derive(Debug, Clone, PartialEq)]
pub struct CropDetailOutput {
    pub crop: CropEntity,
}

impl CropDetailOutput {
    pub fn new(crop: CropEntity) -> Self { Self { crop } }
}

#[derive(Debug, Clone, PartialEq)]
pub struct CropShowDetail {
    pub crop: CropEntity,
}
