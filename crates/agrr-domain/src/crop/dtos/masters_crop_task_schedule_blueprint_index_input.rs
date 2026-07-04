pub struct MastersCropTaskScheduleBlueprintIndexInput {
    pub user_id: i64,
    pub crop_id: i64,
}

impl MastersCropTaskScheduleBlueprintIndexInput {
    pub fn new(user_id: i64, crop_id: i64) -> Self {
        Self { user_id, crop_id }
    }
}
