//! Ruby: `Domain::DeletionUndo::Interactors::DeletionUndoRestoreInteractor`

use crate::deletion_undo::dtos::{DeletionUndoRestoreInput, DeletionUndoRestoreOutput};
use crate::deletion_undo::exceptions::{
    DeletionUndoExpiredError, DeletionUndoNotFoundError, DeletionUndoRestoreConflictError,
};
use crate::deletion_undo::gateways::DeletionUndoGateway;
use crate::deletion_undo::ports::DeletionUndoRestoreOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::ClockPort;

/// Ruby: `Domain::DeletionUndo::Interactors::DeletionUndoRestoreInteractor`
pub struct DeletionUndoRestoreInteractor<'a, G, O, C> {
    output_port: &'a mut O,
    gateway: &'a G,
    clock: &'a C,
}

impl<'a, G, O, C> DeletionUndoRestoreInteractor<'a, G, O, C>
where
    G: DeletionUndoGateway,
    O: DeletionUndoRestoreOutputPort,
    C: ClockPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, clock: &'a C) -> Self {
        Self {
            output_port,
            gateway,
            clock,
        }
    }

    /// Ruby: `#call(input_dto)`
    pub fn call(&mut self, input: DeletionUndoRestoreInput) {
        let undo_token = input.undo_token;

        let event = match self.gateway.find_by_token(&undo_token) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<DeletionUndoNotFoundError>().is_some() {
                    self.output_port.on_failure(Error::new("Not found"));
                } else {
                    self.output_port
                        .on_failure(Error::new(err.to_string()));
                }
                return;
            }
        };

        let now = self.clock.now();
        if event.expired(now) || !event.scheduled() {
            if event.expired(now) {
                let _ = self.gateway.expire_if_needed(&event.id);
            } else {
                let _ = self.gateway.mark_failed(&event.id, "Token expired");
            }
            self.output_port
                .on_failure(Error::new("Undo token has expired"));
            return;
        }

        if let Err(err) = self.gateway.perform_restore(&event.id) {
            if let Some(e) = err.downcast_ref::<DeletionUndoNotFoundError>() {
                let _ = e;
                self.output_port.on_failure(Error::new("Not found"));
            } else if let Some(e) = err.downcast_ref::<DeletionUndoExpiredError>() {
                self.output_port.on_failure(Error::new(e.0.clone()));
            } else if let Some(e) = err.downcast_ref::<DeletionUndoRestoreConflictError>() {
                self.output_port.on_failure(Error::new(e.0.clone()));
            } else if err.downcast_ref::<RecordInvalidError>().is_some() {
                self.output_port.on_failure(Error::new(err.to_string()));
            } else {
                self.output_port.on_failure(Error::new(err.to_string()));
            }
            return;
        }

        self.output_port.on_success(DeletionUndoRestoreOutput::new(
            "restored",
            event.undo_token(),
        ));
    }
}

#[cfg(test)]
mod interactors_deletion_undo_restore_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/deletion_undo/interactors_deletion_undo_restore_interactor_test.rs"));
}
