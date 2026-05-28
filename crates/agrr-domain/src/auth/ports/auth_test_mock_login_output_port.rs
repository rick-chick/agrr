use time::OffsetDateTime;

/// Ruby: `Domain::Auth::Ports::AuthTestMockLoginOutputPort`
pub trait AuthTestMockLoginOutputPort {
    fn on_environment_forbidden(&mut self);
    fn on_missing_mock(&mut self);
    fn on_create_failed(&mut self, error_messages: Vec<String>);
    fn on_success_process_saved_plan(&mut self, session_id: &str, expires_at: OffsetDateTime);
    fn on_success_return_to(
        &mut self,
        url: &str,
        session_id: &str,
        expires_at: OffsetDateTime,
        user_name: &str,
    );
    fn on_success_root(
        &mut self,
        session_id: &str,
        expires_at: OffsetDateTime,
        user_name: &str,
    );
}
