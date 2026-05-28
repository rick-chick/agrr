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
mod tests {
    use super::*;
    use crate::deletion_undo::entities::DeletionUndoEntity;
    use std::collections::BTreeMap;
    use time::macros::datetime;
    use time::{Date, OffsetDateTime};

    struct FixedClock {
        now: OffsetDateTime,
    }

    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            self.now.date()
        }

        fn now(&self) -> OffsetDateTime {
            self.now
        }
    }

    struct SpyOutput {
        success: Option<DeletionUndoRestoreOutput>,
        failure: Option<Error>,
    }

    impl DeletionUndoRestoreOutputPort for SpyOutput {
        fn on_success(&mut self, output: DeletionUndoRestoreOutput) {
            self.success = Some(output);
        }

        fn on_failure(&mut self, error: Error) {
            self.failure = Some(error);
        }
    }

    #[derive(Clone)]
    enum FindBehavior {
        Return(DeletionUndoEntity),
    }

    struct MockGateway {
        find: FindBehavior,
        expire_called: std::sync::atomic::AtomicBool,
        mark_failed_called: std::sync::atomic::AtomicBool,
        restore_called: std::sync::atomic::AtomicBool,
    }

    impl DeletionUndoGateway for MockGateway {
        fn find_by_token(
            &self,
            _undo_token: &str,
        ) -> Result<DeletionUndoEntity, Box<dyn std::error::Error + Send + Sync>> {
            match &self.find {
                FindBehavior::Return(entity) => Ok(entity.clone()),
            }
        }

        fn expire_if_needed(
            &self,
            _event_id: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.expire_called
                .store(true, std::sync::atomic::Ordering::SeqCst);
            Ok(())
        }

        fn perform_restore(
            &self,
            _event_id: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.restore_called
                .store(true, std::sync::atomic::Ordering::SeqCst);
            Ok(())
        }

        fn mark_failed(
            &self,
            _event_id: &str,
            _error_message: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.mark_failed_called
                .store(true, std::sync::atomic::Ordering::SeqCst);
            Ok(())
        }

        fn find_schedulable_record(
            &self,
            _resource_type: &str,
            _resource_id: i64,
        ) -> Result<crate::deletion_undo::schedule_authorization::SchedulableRecord, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }

        fn schedule(
            &self,
            _resource_type: &str,
            _resource_id: i64,
            _actor_id: Option<i64>,
            _toast_message: Option<&str>,
            _auto_hide_after: Option<i64>,
            _metadata: &BTreeMap<String, String>,
            _validate_before_schedule: bool,
        ) -> Result<DeletionUndoEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    fn entity(status: &str) -> DeletionUndoEntity {
        DeletionUndoEntity::new(
            "undo-token-1",
            datetime!(2026-05-01 12:00:00 UTC),
            status,
            BTreeMap::new(),
        )
    }

    // Ruby: test "calls on_success when event is scheduled and not expired for clock.now"
    #[test]
    fn calls_on_success_when_event_is_scheduled_and_not_expired() {
        let frozen_now = datetime!(2026-05-01 11:00:00 UTC);
        let gateway = MockGateway {
            find: FindBehavior::Return(entity("scheduled")),
            expire_called: std::sync::atomic::AtomicBool::new(false),
            mark_failed_called: std::sync::atomic::AtomicBool::new(false),
            restore_called: std::sync::atomic::AtomicBool::new(false),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let clock = FixedClock { now: frozen_now };
        let mut interactor = DeletionUndoRestoreInteractor::new(&mut output, &gateway, &clock);

        interactor.call(DeletionUndoRestoreInput::new("undo-token-1"));

        let success = output.success.expect("on_success");
        assert_eq!(success.status, "restored");
        assert_eq!(success.undo_token, "undo-token-1");
        assert!(gateway.restore_called.load(std::sync::atomic::Ordering::SeqCst));
    }

    // Ruby: test "calls expire_if_needed and on_failure when event is expired for clock.now"
    #[test]
    fn calls_expire_if_needed_and_on_failure_when_event_is_expired() {
        let frozen_now = datetime!(2026-05-01 13:00:00 UTC);
        let gateway = MockGateway {
            find: FindBehavior::Return(entity("scheduled")),
            expire_called: std::sync::atomic::AtomicBool::new(false),
            mark_failed_called: std::sync::atomic::AtomicBool::new(false),
            restore_called: std::sync::atomic::AtomicBool::new(false),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let clock = FixedClock { now: frozen_now };
        let mut interactor = DeletionUndoRestoreInteractor::new(&mut output, &gateway, &clock);

        interactor.call(DeletionUndoRestoreInput::new("undo-token-1"));

        let failure = output.failure.expect("on_failure");
        assert!(failure.message.contains("expired"));
        assert!(gateway.expire_called.load(std::sync::atomic::Ordering::SeqCst));
        assert!(!gateway.restore_called.load(std::sync::atomic::Ordering::SeqCst));
    }

    // Ruby: test "calls mark_failed and on_failure when event is not scheduled but not expired for clock.now"
    #[test]
    fn calls_mark_failed_and_on_failure_when_event_is_not_scheduled() {
        let frozen_now = datetime!(2026-05-01 11:00:00 UTC);
        let gateway = MockGateway {
            find: FindBehavior::Return(entity("restored")),
            expire_called: std::sync::atomic::AtomicBool::new(false),
            mark_failed_called: std::sync::atomic::AtomicBool::new(false),
            restore_called: std::sync::atomic::AtomicBool::new(false),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let clock = FixedClock { now: frozen_now };
        let mut interactor = DeletionUndoRestoreInteractor::new(&mut output, &gateway, &clock);

        interactor.call(DeletionUndoRestoreInput::new("undo-token-1"));

        assert!(output.failure.is_some());
        assert!(gateway.mark_failed_called.load(std::sync::atomic::Ordering::SeqCst));
        assert!(!gateway.restore_called.load(std::sync::atomic::Ordering::SeqCst));
    }
}
