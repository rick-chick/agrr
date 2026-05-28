/// Ruby: `Domain::ApiKeys::Ports::UserApiKeyRotateOutputPort`
pub trait UserApiKeyRotateOutputPort: Send {
    fn on_success(&mut self, api_key: String);
    fn on_failure(&mut self, message: String);
}
