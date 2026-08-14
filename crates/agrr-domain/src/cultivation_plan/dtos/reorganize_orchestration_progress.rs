//! Persisted Reorganize orchestration step progress for Learn master-update flow.

pub const PIPELINE_PHASE_IDLE: &str = "idle";
pub const PIPELINE_PHASE_PLACEMENT: &str = "placement";
pub const PIPELINE_PHASE_OPTIMIZING: &str = "optimizing";
pub const PIPELINE_PHASE_REGENERATE: &str = "regenerate";
pub const PIPELINE_PHASE_SYNC_VERIFY: &str = "sync_verify";
pub const PIPELINE_PHASE_FAILED: &str = "failed";
pub const PIPELINE_PHASE_COMPLETED: &str = "completed";

pub const PIPELINE_PHASES: &[&str] = &[
    PIPELINE_PHASE_IDLE,
    PIPELINE_PHASE_PLACEMENT,
    PIPELINE_PHASE_OPTIMIZING,
    PIPELINE_PHASE_REGENERATE,
    PIPELINE_PHASE_SYNC_VERIFY,
    PIPELINE_PHASE_FAILED,
    PIPELINE_PHASE_COMPLETED,
];

#[derive(Debug, Clone, PartialEq)]
pub struct ReorganizeOrchestrationProgressRead {
    pub placement: bool,
    pub regenerate: bool,
    pub sync_verify: bool,
    pub return_to_learn: bool,
    pub pipeline_active: bool,
    pub current_phase: String,
    pub last_error: Option<String>,
}

impl Default for ReorganizeOrchestrationProgressRead {
    fn default() -> Self {
        Self {
            placement: false,
            regenerate: false,
            sync_verify: false,
            return_to_learn: false,
            pipeline_active: false,
            current_phase: PIPELINE_PHASE_IDLE.to_string(),
            last_error: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct ReorganizeOrchestrationProgressPatch {
    pub placement: Option<bool>,
    pub regenerate: Option<bool>,
    pub sync_verify: Option<bool>,
    pub return_to_learn: Option<bool>,
    pub pipeline_active: Option<bool>,
    pub current_phase: Option<String>,
    pub last_error: Option<Option<String>>,
}

impl ReorganizeOrchestrationProgressPatch {
    pub fn is_empty(&self) -> bool {
        self.placement.is_none()
            && self.regenerate.is_none()
            && self.sync_verify.is_none()
            && self.return_to_learn.is_none()
            && self.pipeline_active.is_none()
            && self.current_phase.is_none()
            && self.last_error.is_none()
    }
}
