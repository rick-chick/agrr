/// Ruby: `Domain::Auth::Gateways::UserSessionRevocationGateway`
pub trait UserSessionRevocationGateway: Send + Sync {
    /// Revokes a single session (current-device logout).
    fn delete_session_by_session_id(&self, session_id: &str);

    /// Revokes every session for account deletion and global sign-out.
    fn delete_all_sessions_for_user(&self, user_id: i64);
}
