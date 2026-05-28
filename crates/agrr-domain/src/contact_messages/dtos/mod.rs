mod create_contact_message_failure;
mod create_contact_message_input;
mod create_contact_message_success;

pub use create_contact_message_failure::{
    CreateContactMessageFailure, CreateContactMessageFailureKind,
};
pub use create_contact_message_input::CreateContactMessageInput;
pub use create_contact_message_success::CreateContactMessageSuccess;
