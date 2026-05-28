use crate::crop::dtos::{MastersCropTaskTemplate, MastersCropTaskTemplateCreateFailure};

#[derive(Debug, Clone)]
pub struct MastersCropTaskTemplateCreateOutput {
    pub template: Option<MastersCropTaskTemplate>,
    pub failure: Option<MastersCropTaskTemplateCreateFailure>,
}

impl MastersCropTaskTemplateCreateOutput {
    pub fn success(template: MastersCropTaskTemplate) -> Self {
        Self {
            template: Some(template),
            failure: None,
        }
    }

    pub fn failure(failure: MastersCropTaskTemplateCreateFailure) -> Self {
        Self {
            template: None,
            failure: Some(failure),
        }
    }

    pub fn is_success(&self) -> bool {
        self.template.is_some()
    }

    pub fn is_failure(&self) -> bool {
        self.failure.is_some()
    }
}
