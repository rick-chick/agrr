#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropFindReferenceForEntryScheduleInput {
    pub crop_id: i64,
    pub region: Option<String>,
}

impl CropFindReferenceForEntryScheduleInput {
    pub fn new(crop_id: i64, region: Option<String>) -> Self { Self { crop_id, region } }
}
