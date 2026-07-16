use serde_json::Value;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CropSetupProposalMode {
    DryRun,
    Apply,
}

#[derive(Debug, Clone)]
pub struct CropSetupProposalInput {
    pub user_id: i64,
    pub crop_id: i64,
    pub mode: CropSetupProposalMode,
    pub body: Value,
}

impl CropSetupProposalInput {
    pub fn new(user_id: i64, crop_id: i64, mode: CropSetupProposalMode, body: Value) -> Self {
        Self {
            user_id,
            crop_id,
            mode,
            body,
        }
    }
}
