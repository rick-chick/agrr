/// Ruby: `Domain::Auth::Gateways::UserSessionRevocationGateway`
pub trait UserSessionRevocationGateway: Send + Sync {
    fn delete_all_sessions_for_user(&self, user_id: i64);
}
