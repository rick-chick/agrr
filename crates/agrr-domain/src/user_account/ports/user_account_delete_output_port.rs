/// Ruby: `Domain::UserAccount::Ports::UserAccountDeleteOutputPort`
pub trait UserAccountDeleteOutputPort {
    fn on_success(&mut self);
    fn on_not_confirmed(&mut self);
    fn on_failure(&mut self, message: String);
}
