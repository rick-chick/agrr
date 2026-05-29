//! Deletion undo scheduling (Rails-compatible snapshots).

mod deletion_undo_gateway;
pub mod restore;
pub mod schedule;

pub use deletion_undo_gateway::DeletionUndoSqliteGateway;
pub use schedule::{schedule_destroy, ScheduledUndo};
