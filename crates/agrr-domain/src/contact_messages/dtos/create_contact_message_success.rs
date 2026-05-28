//! Ruby: `Domain::ContactMessages::Dtos::CreateContactMessageSuccess`

use crate::contact_messages::entities::ContactMessage;

/// Ruby: `Domain::ContactMessages::Dtos::CreateContactMessageSuccess`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreateContactMessageSuccess {
    pub contact_message: ContactMessage,
}

impl CreateContactMessageSuccess {
    pub fn new(contact_message: ContactMessage) -> Self {
        Self { contact_message }
    }
}
