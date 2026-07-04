use serde_json::Value;

pub struct MastersCropTaskScheduleBlueprintUpdateInput {
    pub user_id: i64,
    pub crop_id: i64,
    pub blueprint_id: i64,
    pub attributes: Value,
}
