#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MastersCropTaskTemplateMastersFailureReason {
    CropNotFound,
    AssociationNotFound,
    ValidationFailed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MastersCropTaskTemplateMastersFailure {
    pub reason: MastersCropTaskTemplateMastersFailureReason,
    pub errors: Vec<String>,
}

impl MastersCropTaskTemplateMastersFailure {
    pub fn new(reason: MastersCropTaskTemplateMastersFailureReason) -> Self {
        Self { reason, errors: vec![] }
    }

    pub fn validation_failed(errors: Vec<String>) -> Self {
        Self { reason: MastersCropTaskTemplateMastersFailureReason::ValidationFailed, errors }
    }
}
