use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct MastersCropTaskTemplateUpdateInput {
    pub user_id: i64,
    pub crop_id: i64,
    pub template_id: i64,
    pub attributes: Value,
}
