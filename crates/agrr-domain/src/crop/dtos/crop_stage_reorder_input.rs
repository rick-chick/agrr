/// Ruby: `Domain::Crop::Dtos::CropStageReorderInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropStageOrderEntry {
    pub stage_id: i64,
    pub order: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropStageReorderInput {
    pub crop_id: i64,
    pub orders: Vec<CropStageOrderEntry>,
}

impl CropStageReorderInput {
    pub fn new(crop_id: i64, orders: Vec<CropStageOrderEntry>) -> Self {
        Self { crop_id, orders }
    }
}
