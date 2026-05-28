#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MastersCropTaskTemplateDestroyInput {
    pub user_id: i64,
    pub crop_id: i64,
    pub template_id: i64,
}
