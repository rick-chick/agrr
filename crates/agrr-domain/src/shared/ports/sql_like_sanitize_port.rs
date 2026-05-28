/// Ruby: `Domain::Shared::Ports::SqlLikeSanitizePort`
pub trait SqlLikeSanitizePort: Send + Sync {
    fn sanitize_like(&self, term: &str) -> String;
}
