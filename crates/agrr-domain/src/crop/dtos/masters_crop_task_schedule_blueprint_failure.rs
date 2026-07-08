#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MastersCropTaskScheduleBlueprintFailureReason {
    CropNotFound,
    BlueprintNotFound,
    Duplicate,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MastersCropTaskScheduleBlueprintFailure {
    pub reason: MastersCropTaskScheduleBlueprintFailureReason,
    pub errors: Vec<String>,
}

impl MastersCropTaskScheduleBlueprintFailure {
    pub fn new(reason: MastersCropTaskScheduleBlueprintFailureReason) -> Self {
        Self {
            reason,
            errors: vec![],
        }
    }
}
