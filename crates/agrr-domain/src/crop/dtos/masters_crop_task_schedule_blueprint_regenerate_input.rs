pub struct MastersCropTaskScheduleBlueprintRegenerateInput {
    pub user_id: i64,
    pub crop_id: i64,
}

impl MastersCropTaskScheduleBlueprintRegenerateInput {
    pub fn new(user_id: i64, crop_id: i64) -> Self {
        Self { user_id, crop_id }
    }
}

/// System-triggered regeneration (no user authorization).
pub struct CropRegenerateTaskScheduleBlueprintsInput {
    pub crop_id: i64,
}

impl CropRegenerateTaskScheduleBlueprintsInput {
    pub fn new(crop_id: i64) -> Self {
        Self { crop_id }
    }
}
