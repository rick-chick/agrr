//! Ports for private plan create readiness checks.

use crate::shared::user::User;

pub trait PrivatePlanCreateReadinessGateway: Send + Sync {
    fn user_has_ready_crop(
        &self,
        user: &User,
    ) -> Result<bool, Box<dyn std::error::Error + Send + Sync>>;
}
