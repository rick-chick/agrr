//! Ruby: `Domain::ContactMessages::Gateways::ContactMessageGateway`

use crate::contact_messages::dtos::CreateContactMessageInput;
use crate::contact_messages::entities::ContactMessage;

/// Ruby: `Domain::ContactMessages::Gateways::ContactMessageGateway`
pub trait ContactMessageGateway: Send + Sync {
    fn find_by_id(&self, id: i64) -> Option<ContactMessage>;

    fn create(
        &self,
        input: &CreateContactMessageInput,
    ) -> Result<ContactMessage, Box<dyn std::error::Error + Send + Sync>>;
}
