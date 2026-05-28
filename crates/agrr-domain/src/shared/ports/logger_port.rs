/// Ruby: `Domain::Shared::Ports::LoggerPort`
pub trait LoggerPort: Send + Sync {
    fn info(&self, message: &str);
    fn warn(&self, message: &str);
    fn error(&self, message: &str);
    fn debug(&self, message: &str);
}
