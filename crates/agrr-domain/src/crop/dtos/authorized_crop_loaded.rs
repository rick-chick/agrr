use crate::crop::entities::CropEntity;

#[derive(Debug, Clone, PartialEq)]
pub struct AuthorizedCropLoaded {
    pub crop_entity: CropEntity,
}

impl AuthorizedCropLoaded {
    pub fn new(crop_entity: CropEntity) -> Self { Self { crop_entity } }
}
