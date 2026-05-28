#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CropStageCopyInput {
    pub reference_crop_id: i64,
    pub new_crop_id: i64,
}
