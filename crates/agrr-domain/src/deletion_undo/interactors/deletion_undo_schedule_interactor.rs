//! Ruby: `Domain::DeletionUndo::Interactors::DeletionUndoScheduleInteractor`

use crate::deletion_undo::dtos::{DeletionUndoScheduleFailure, DeletionUndoScheduleInput};
use crate::deletion_undo::exceptions::DeletionUndoError;
use crate::deletion_undo::gateways::DeletionUndoGateway;
use crate::deletion_undo::ports::{ActorLookupPort, DeletionUndoScheduleOutputPort};
use crate::deletion_undo::schedule_authorization::schedule_allowed;
use crate::shared::exceptions::{AssociationInUseError, RecordInvalidError};
use crate::shared::hash::present;
use serde_json::Value;

/// Ruby: `ArgumentError` for missing resource identifiers.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ArgumentError(pub String);

/// Ruby: `Domain::DeletionUndo::Interactors::DeletionUndoScheduleInteractor`
pub struct DeletionUndoScheduleInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_lookup: &'a L,
}

impl<'a, G, O, L> DeletionUndoScheduleInteractor<'a, G, O, L>
where
    G: DeletionUndoGateway,
    O: DeletionUndoScheduleOutputPort,
    L: ActorLookupPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, user_lookup: &'a L) -> Self {
        Self {
            output_port,
            gateway,
            user_lookup,
        }
    }

    /// Ruby: `#call(input_dto)`
    pub fn call(&mut self, input: DeletionUndoScheduleInput) -> Result<(), ArgumentError> {
        if !present(&Value::String(input.resource_type.clone())) || input.resource_id.is_none() {
            return Err(ArgumentError(
                "resource_type and resource_id are required".into(),
            ));
        }
        let resource_id = input.resource_id.expect("checked above");

        if let Err(()) = self.ensure_schedule_authorized(&input) {
            self.output_port
                .on_failure(DeletionUndoScheduleFailure::forbidden());
            return Ok(());
        }

        match self.gateway.schedule(
            &input.resource_type,
            resource_id,
            input.actor_id,
            input.toast_message.as_deref(),
            input.auto_hide_after,
            &input.metadata,
            input.validate_before_schedule,
        ) {
            Ok(event) => {
                self.output_port.on_success(event);
                Ok(())
            }
            Err(err) => {
                if let Some(e) = err.downcast_ref::<DeletionUndoError>() {
                    self.output_port.on_failure(DeletionUndoScheduleFailure::undo_system_error(
                        e.0.clone(),
                    ));
                } else if let Some(record_invalid) = err.downcast_ref::<RecordInvalidError>() {
                    let msg = record_invalid
                        .detail_message()
                        .unwrap_or("record invalid")
                        .to_string();
                    self.output_port
                        .on_failure(DeletionUndoScheduleFailure::validation_error(msg));
                } else if err.downcast_ref::<AssociationInUseError>().is_some() {
                    self.output_port.on_failure(DeletionUndoScheduleFailure::association_in_use(
                        "association in use".to_string(),
                    ));
                } else {
                    return Err(ArgumentError(err.to_string()));
                }
                Ok(())
            }
        }
    }

    fn ensure_schedule_authorized(&self, input: &DeletionUndoScheduleInput) -> Result<(), ()> {
        let user = self.user_lookup.find(input.actor_id).map_err(|_| ())?;
        let resource_id = input.resource_id.ok_or(())?;
        let record = self
            .gateway
            .find_schedulable_record(&input.resource_type, resource_id)
            .map_err(|_| ())?;
        if schedule_allowed(&user, &record) {
            Ok(())
        } else {
            Err(())
        }
    }
}

#[cfg(test)]
mod interactors_deletion_undo_schedule_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/deletion_undo/interactors_deletion_undo_schedule_interactor_test.rs"));
}
