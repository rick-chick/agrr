/// Ruby: `Domain::AgriculturalTask::Entities::CropTaskTemplateLinkEntity`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropTaskTemplateLinkEntity {
    pub crop_id: i64,
}

impl CropTaskTemplateLinkEntity {
    pub fn new(crop_id: i64) -> Self {
        Self { crop_id }
    }
}
