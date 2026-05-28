#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MastersCropTaskTemplateCreateFailureReason {
    MissingAgriculturalTaskId,
    CropNotFound,
    AgriculturalTaskNotFound,
    Forbidden,
    Duplicate,
    ValidationFailed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MastersCropTaskTemplateCreateFailure {
    pub reason: MastersCropTaskTemplateCreateFailureReason,
    pub errors: Vec<String>,
}

impl MastersCropTaskTemplateCreateFailure {
    pub fn new(reason: MastersCropTaskTemplateCreateFailureReason) -> Self {
        Self { reason, errors: vec![] }
    }

    pub fn validation_failed(errors: Vec<String>) -> Self {
        Self { reason: MastersCropTaskTemplateCreateFailureReason::ValidationFailed, errors }
    }
}
