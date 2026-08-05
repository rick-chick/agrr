/// Ruby: `Domain::ApiKeys::Ports::UserApiKeyRotateOutputPort`
pub trait UserApiKeyRotateOutputPort: Send {
    fn on_success(&mut self, api_key: String, scopes: Vec<String>);
    fn on_failure(&mut self, message: String);
}
