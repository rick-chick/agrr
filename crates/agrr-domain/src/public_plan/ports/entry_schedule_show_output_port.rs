use crate::public_plan::dtos::{EntryScheduleFailure, EntryScheduleShowOutput};

/// Ruby: `Domain::PublicPlan::Ports::EntryScheduleShowOutputPort`
pub trait EntryScheduleShowOutputPort {
    fn on_success(&mut self, success_dto: EntryScheduleShowOutput);
    fn on_failure(&mut self, failure_dto: EntryScheduleFailure);
}
