#[derive(Debug, Clone, PartialEq)]
pub struct MastersCropTaskScheduleBlueprintCreateInput {
    pub user_id: i64,
    pub crop_id: i64,
    pub agricultural_task_id: Option<i64>,
    pub stage_order: Option<i32>,
    pub stage_name: Option<String>,
    pub gdd_trigger: Option<f64>,
    pub task_type: Option<String>,
    pub description: Option<String>,
    pub priority: Option<i32>,
}
