/// Ruby: `Domain::Pest::Entities::CropPestLinkEntity`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CropPestLinkEntity {
    pub id: i64,
    pub crop_id: i64,
    pub pest_id: i64,
}

impl CropPestLinkEntity {
    pub fn new(id: i64, crop_id: i64, pest_id: i64) -> Self {
        Self {
            id,
            crop_id,
            pest_id,
        }
    }
}
