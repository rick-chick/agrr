#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropStageReorderEntry {
    pub crop_stage_id: i64,
    pub order: i64,
}

/// Ruby: `Domain::Crop::Dtos::CropStageReorderInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropStageReorderInput {
    pub crop_id: i64,
    pub entries: Vec<CropStageReorderEntry>,
}
