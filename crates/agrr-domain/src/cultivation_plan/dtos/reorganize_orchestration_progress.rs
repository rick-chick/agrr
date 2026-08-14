//! Persisted Reorganize orchestration step progress for Learn master-update flow.

#[derive(Debug, Clone, PartialEq, Default)]
pub struct ReorganizeOrchestrationProgressRead {
    pub placement: bool,
    pub regenerate: bool,
    pub sync_verify: bool,
    pub return_to_learn: bool,
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct ReorganizeOrchestrationProgressPatch {
    pub placement: Option<bool>,
    pub regenerate: Option<bool>,
    pub sync_verify: Option<bool>,
    pub return_to_learn: Option<bool>,
}

impl ReorganizeOrchestrationProgressPatch {
    pub fn is_empty(&self) -> bool {
        self.placement.is_none()
            && self.regenerate.is_none()
            && self.sync_verify.is_none()
            && self.return_to_learn.is_none()
    }
}
