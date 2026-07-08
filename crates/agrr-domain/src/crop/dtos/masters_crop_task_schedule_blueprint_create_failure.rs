#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MastersCropTaskScheduleBlueprintCreateFailureReason {
    MissingAgriculturalTaskId,
    MissingGddTrigger,
    InvalidStageOrder,
    CropNotFound,
    AgriculturalTaskNotFound,
    Duplicate,
    ValidationFailed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MastersCropTaskScheduleBlueprintCreateFailure {
    pub reason: MastersCropTaskScheduleBlueprintCreateFailureReason,
    pub errors: Vec<String>,
}

impl MastersCropTaskScheduleBlueprintCreateFailure {
    pub fn new(reason: MastersCropTaskScheduleBlueprintCreateFailureReason) -> Self {
        Self {
            reason,
            errors: vec![],
        }
    }

    pub fn validation_failed(errors: Vec<String>) -> Self {
        Self {
            reason: MastersCropTaskScheduleBlueprintCreateFailureReason::ValidationFailed,
            errors,
        }
    }
}
