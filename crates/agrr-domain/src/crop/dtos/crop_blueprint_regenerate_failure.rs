#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CropBlueprintRegenerateFailureReason {
    CropNotFound,
    MissingTaskTemplates,
    MissingAgrrRequirement,
    BlueprintRegenerationFromAgrrFailed,
    AiUnavailable,
    AiExecutionFailed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropBlueprintRegenerateFailure {
    pub reason: CropBlueprintRegenerateFailureReason,
    pub message: String,
}

impl CropBlueprintRegenerateFailure {
    pub fn new(reason: CropBlueprintRegenerateFailureReason, message: impl Into<String>) -> Self {
        Self {
            reason,
            message: message.into(),
        }
    }
}
