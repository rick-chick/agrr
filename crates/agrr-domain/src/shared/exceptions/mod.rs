//! Ruby: `Domain::Shared::Exceptions::*` as `thiserror` types.

use crate::shared::validation::ValidationErrors;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
#[error("record not found")]
pub struct RecordNotFoundError;

#[derive(Debug, thiserror::Error)]
#[error("record invalid{message}", message = display_message(.message))]
pub struct RecordInvalidError {
    message: Option<String>,
    pub errors: Option<ValidationErrors>,
}

impl RecordInvalidError {
    pub fn new(message: Option<String>, errors: Option<ValidationErrors>) -> Self {
        Self { message, errors }
    }

  pub fn detail_message(&self) -> Option<&str> {
        self.message.as_deref()
    }

    /// Ruby: `RecordInvalid#flatten_error_messages`
    pub fn flatten_error_messages(&self) -> Vec<String> {
        match &self.errors {
            None => vec![],
            Some(ve) => ve.full_messages(),
        }
    }
}

fn display_message(message: &Option<String>) -> String {
    match message {
        Some(m) => format!(": {m}"),
        None => String::new(),
    }
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
#[error("persistence failed")]
pub struct PersistenceFailedError;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
#[error("association in use")]
pub struct AssociationInUseError;

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
#[error("invalid task schedule item")]
pub struct InvalidTaskScheduleItemError;

/// Union of shared domain failures (Interactor `Result` boundary).
#[derive(Debug, thiserror::Error)]
pub enum SharedDomainError {
    #[error(transparent)]
    RecordNotFound(#[from] RecordNotFoundError),
    #[error(transparent)]
    RecordInvalid(#[from] RecordInvalidError),
    #[error(transparent)]
    PersistenceFailed(#[from] PersistenceFailedError),
    #[error(transparent)]
    AssociationInUse(#[from] AssociationInUseError),
    #[error(transparent)]
    InvalidTaskScheduleItem(#[from] InvalidTaskScheduleItemError),
}
