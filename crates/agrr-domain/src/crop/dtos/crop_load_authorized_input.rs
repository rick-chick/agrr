#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CropLoadAuthorizedInput {
    pub crop_id: i64,
    pub for_edit: bool,
}

impl CropLoadAuthorizedInput {
    pub fn new(crop_id: i64, for_edit: bool) -> Self { Self { crop_id, for_edit } }
}
