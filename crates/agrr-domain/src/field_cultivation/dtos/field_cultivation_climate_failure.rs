#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FieldCultivationClimateFailureReason {
    ProgressDaemonUnavailable,
    ProgressExecutionFailed,
    ProgressResultInvalid,
    CropRequirementIncomplete,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldCultivationClimateFailure {
    pub reason: FieldCultivationClimateFailureReason,
    pub message: String,
}

impl FieldCultivationClimateFailure {
    pub fn new(reason: FieldCultivationClimateFailureReason, message: impl Into<String>) -> Self {
        Self {
            reason,
            message: message.into(),
        }
    }
}

impl std::fmt::Display for FieldCultivationClimateFailure {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.message)
    }
}
