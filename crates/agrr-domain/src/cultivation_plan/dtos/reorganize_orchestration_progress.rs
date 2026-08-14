//! Persisted Reorganize orchestration step progress for Learn master-update flow.

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub enum ReorganizePipelinePhase {
    #[default]
    Placement,
    Optimizing,
    Regenerate,
    SyncVerify,
}

impl ReorganizePipelinePhase {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Placement => "placement",
            Self::Optimizing => "optimizing",
            Self::Regenerate => "regenerate",
            Self::SyncVerify => "sync_verify",
        }
    }

    pub fn parse(raw: &str) -> Option<Self> {
        match raw {
            "placement" => Some(Self::Placement),
            "optimizing" => Some(Self::Optimizing),
            "regenerate" => Some(Self::Regenerate),
            "sync_verify" => Some(Self::SyncVerify),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct ReorganizeOrchestrationProgressRead {
    pub placement: bool,
    pub regenerate: bool,
    pub sync_verify: bool,
    pub return_to_learn: bool,
    pub pipeline_active: bool,
    pub pipeline_phase: Option<ReorganizePipelinePhase>,
    pub pipeline_failed_phase: Option<ReorganizePipelinePhase>,
    pub pipeline_error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct ReorganizeOrchestrationProgressPatch {
    pub placement: Option<bool>,
    pub regenerate: Option<bool>,
    pub sync_verify: Option<bool>,
    pub return_to_learn: Option<bool>,
    pub pipeline_active: Option<bool>,
    pub pipeline_phase: Option<Option<ReorganizePipelinePhase>>,
    pub pipeline_failed_phase: Option<Option<ReorganizePipelinePhase>>,
    pub pipeline_error: Option<Option<String>>,
}

impl ReorganizeOrchestrationProgressPatch {
    pub fn is_empty(&self) -> bool {
        self.placement.is_none()
            && self.regenerate.is_none()
            && self.sync_verify.is_none()
            && self.return_to_learn.is_none()
            && self.pipeline_active.is_none()
            && self.pipeline_phase.is_none()
            && self.pipeline_failed_phase.is_none()
            && self.pipeline_error.is_none()
    }
}
