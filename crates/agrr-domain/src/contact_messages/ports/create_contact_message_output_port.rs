//! Ruby: `Domain::ContactMessages::Ports::CreateContactMessageOutputPort`

use crate::contact_messages::dtos::{CreateContactMessageFailure, CreateContactMessageSuccess};

/// Ruby: `Domain::ContactMessages::Ports::CreateContactMessageOutputPort`
pub trait CreateContactMessageOutputPort {
    fn on_success(&mut self, success_dto: CreateContactMessageSuccess);
    fn on_failure(&mut self, failure_dto: CreateContactMessageFailure);
}
