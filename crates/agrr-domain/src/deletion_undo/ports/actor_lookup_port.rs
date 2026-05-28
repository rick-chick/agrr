//! Actor lookup for schedule authorization (`user_lookup.find(actor_id)` may receive nil).

use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::user::User;

/// Ruby: `user_lookup.find(input_dto.actor_id)` — `actor_id` may be nil.
pub trait ActorLookupPort: Send + Sync {
    fn find(&self, actor_id: Option<i64>) -> Result<User, RecordNotFoundError>;
}
