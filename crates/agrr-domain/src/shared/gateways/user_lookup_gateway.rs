use crate::shared::user::User;

/// Ruby: `Domain::Shared::Gateways::UserLookupGateway`
pub trait UserLookupGateway: Send + Sync {
    /// Ruby: `#find(user_id)` — `Domain::Shared::Dtos::User`
    fn find(&self, user_id: i64) -> User;
}
