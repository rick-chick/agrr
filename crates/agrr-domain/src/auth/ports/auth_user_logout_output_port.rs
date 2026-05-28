/// Ruby: `Domain::Auth::Ports::AuthUserLogoutOutputPort`
pub trait AuthUserLogoutOutputPort {
    fn on_success(&mut self);
    fn on_not_logged_in(&mut self);
}
