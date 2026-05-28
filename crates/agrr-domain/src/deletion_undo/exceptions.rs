//! Ruby: `Domain::DeletionUndo::Exceptions`

use thiserror::Error;

/// Ruby: `DeletionUndoError`
#[derive(Debug, Error, PartialEq, Eq)]
#[error("{0}")]
pub struct DeletionUndoError(pub String);

/// Ruby: `DeletionUndoNotFoundError`
#[derive(Debug, Error, PartialEq, Eq)]
#[error("deletion undo not found")]
pub struct DeletionUndoNotFoundError;

/// Ruby: `DeletionUndoExpiredError`
#[derive(Debug, Error, PartialEq, Eq)]
#[error("{0}")]
pub struct DeletionUndoExpiredError(pub String);

/// Ruby: `DeletionUndoRestoreConflictError`
#[derive(Debug, Error, PartialEq, Eq)]
#[error("{0}")]
pub struct DeletionUndoRestoreConflictError(pub String);
